#include "ninfer_build_id.h"
#include "product/logging/logging.h"
#include "product/logging/startup_log.h"
#include "serve/generation_service.h"
#include "serve/http_server.h"
#include "serve/serve_options.h"

#include <spdlog/logger.h>

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <utility>

namespace {

std::atomic<ninfer::serve::HttpServer*> g_server{nullptr};

void handle_signal(int) {
    ninfer::serve::HttpServer* server = g_server.load();
    if (server != nullptr) { server->stop(); }
}

// An exception that escapes a request boundary ends the process through std::terminate, and the
// default handler's message is the only record of which exception it was. Under a container this
// process is pid 1: the kernel discards the SIGABRT that abort() raises against itself, glibc falls
// through to its abort instruction, and all the kernel reports is a protection fault inside libc.
[[noreturn]] void log_terminate() {
    std::string detail = "terminate called with no active exception";
    if (std::current_exception() != nullptr) {
        try {
            std::rethrow_exception(std::current_exception());
        } catch (const std::exception& error) {
            detail = std::string("terminate called after throwing ") + typeid(error).name() + ": " +
                     error.what();
        } catch (...) { detail = "terminate called after throwing a non-std exception"; }
    }
    std::fprintf(stderr, "ninfer-serve: %s\n", detail.c_str());
    std::fflush(stderr);
    std::abort();
}

} // namespace

int main(int argc, char** argv) {
    std::set_terminate(log_terminate);
    ninfer::serve::ServeOptions options;
    try {
        options = ninfer::serve::parse_serve_options(argc, argv);
    } catch (const std::invalid_argument& exception) {
        std::cerr << "ninfer-serve: " << exception.what() << '\n';
        std::cerr << ninfer::serve::serve_usage_text(argv[0]);
        return 1;
    } catch (const std::exception& exception) {
        std::cerr << "ninfer-serve: " << exception.what() << '\n';
        return 1;
    }
    if (options.help_requested) {
        std::cout << ninfer::serve::serve_usage_text(argv[0]);
        return 0;
    }

    ninfer::product::LoggingRuntime logging(
        {.logger_name  = "ninfer-serve",
         .level        = options.log_level,
         .presentation = ninfer::product::LogPresentation::Service});
    const std::shared_ptr<spdlog::logger> logger = logging.logger();
    ninfer::product::StartupLogRenderer startup_log(logging);
    ninfer::serve::OperationalLog operational_log(logger);
    bool serving = false;

    try {
        ninfer::serve::HttpServer server(options, logger);
        if (!server.bind()) {
            operational_log.bind_failure(options.host, options.port);
            return 1;
        }

        // Answer 503 from here on rather than leaving the accepted connection silent. The socket
        // has been listenable since bind() either way; the difference is whether a caller arriving
        // during the ten seconds of weight loading gets a documented "still loading" or a hang.
        server.start_serving_during_startup();
        logger->info("build {}", NINFER_BUILD_ID);

        ninfer::serve::GenerationService service(options, startup_log.observer());
        startup_log.engine_ready(service.load_summary());
        operational_log.engine_capacity(service);

        using Clock                            = std::chrono::steady_clock;
        const Clock::time_point warmup_started = Clock::now();
        operational_log.warmup_started();
        try {
            service.warmup();
        } catch (const std::exception& exception) {
            const double seconds =
                std::chrono::duration<double>(Clock::now() - warmup_started).count();
            operational_log.warmup_failure(seconds, exception.what());
            return 1;
        }
        operational_log.warmup_complete(
            std::chrono::duration<double>(Clock::now() - warmup_started).count());
        server.attach(service);

        g_server.store(&server);
        std::signal(SIGINT, handle_signal);
        std::signal(SIGTERM, handle_signal);
#ifdef SIGBREAK
        // Windows has no way to deliver SIGTERM to another process: TerminateProcess kills it
        // outright and the shutdown path -- which flushes the final partial throughput interval --
        // never runs. GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT) is the one graceful stop a parent
        // can request, and the CRT raises it as SIGBREAK.
        std::signal(SIGBREAK, handle_signal);
#endif

        serving = true;
        operational_log.server_ready(options.host, options.port, server.public_model_id(),
                                     !options.api_key.empty());
        operational_log.server_urls(options.host, options.port, server.webui_enabled());

        const bool ok = server.listen();
        g_server.store(nullptr);
        if (!ok) {
            operational_log.listen_failure(options.host, options.port);
            return 1;
        }
        operational_log.server_stopped();
        return 0;
    } catch (const std::exception& exception) {
        g_server.store(nullptr);
        operational_log.server_failure(serving, exception.what());
        return 1;
    }
}
