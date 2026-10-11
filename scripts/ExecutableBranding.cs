// Copyright 2026 NInferEZ Engine contributors.
// SPDX-License-Identifier: Apache-2.0
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

public static class ExecutableBranding
{
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr BeginUpdateResource(string fileName, bool deleteExistingResources);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool UpdateResource(IntPtr update, IntPtr type, IntPtr name, ushort language, byte[] data, uint size);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool EndUpdateResource(IntPtr update, bool discard);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr LoadLibraryEx(string fileName, IntPtr reserved, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr FindResource(IntPtr module, IntPtr name, IntPtr type);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern uint SizeofResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")]
    private static extern bool FreeLibrary(IntPtr module);

    public static void WriteIcon(string outputPath, byte[][] images, int[] sizes)
    {
        if(images.Length!=sizes.Length || images.Length==0) throw new ArgumentException("Expected one PNG per icon size.");
        using(var stream=File.Create(outputPath))
        using(var writer=new BinaryWriter(stream))
        {
            writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)images.Length);
            uint offset=(uint)(6+16*images.Length);
            for(int i=0;i<images.Length;i++)
            {
                if(sizes[i]<1 || sizes[i]>256) throw new ArgumentException("Windows icon sizes must be 1 to 256.");
                writer.Write((byte)(sizes[i]==256?0:sizes[i])); writer.Write((byte)(sizes[i]==256?0:sizes[i]));
                writer.Write((byte)0); writer.Write((byte)0); writer.Write((ushort)1); writer.Write((ushort)32);
                writer.Write((uint)images[i].Length); writer.Write(offset); offset+=(uint)images[i].Length;
            }
            foreach(var image in images) writer.Write(image);
        }
    }

    public static void ApplyIcon(string executable, string iconPath)
    {
        byte[] icon=File.ReadAllBytes(iconPath);
        if(icon.Length<6 || BitConverter.ToUInt16(icon,0)!=0 || BitConverter.ToUInt16(icon,2)!=1)
            throw new InvalidDataException("Expected a valid Windows ICO file.");
        int count=BitConverter.ToUInt16(icon,4);
        if(count==0 || count>64 || icon.Length<6+count*16) throw new InvalidDataException("Invalid ICO directory.");
        IntPtr update=BeginUpdateResource(executable,false);
        if(update==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            using(var groupStream=new MemoryStream())
            using(var groupWriter=new BinaryWriter(groupStream))
            {
                groupWriter.Write((ushort)0); groupWriter.Write((ushort)1); groupWriter.Write((ushort)count);
                for(int i=0;i<count;i++)
                {
                    int entry=6+i*16;
                    uint length=BitConverter.ToUInt32(icon,entry+8), offset=BitConverter.ToUInt32(icon,entry+12);
                    if(length>Int32.MaxValue || (long)offset+length>icon.Length) throw new InvalidDataException("Invalid ICO image range.");
                    byte[] png=new byte[(int)length]; Array.Copy(icon,(int)offset,png,0,png.Length);
                    ushort id=(ushort)(101+i);
                    if(!UpdateResource(update,new IntPtr(3),new IntPtr(id),1033,png,length))
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    groupWriter.Write(icon,entry,12); groupWriter.Write(id);
                }
                byte[] group=groupStream.ToArray();
                if(!UpdateResource(update,new IntPtr(14),new IntPtr(1),1033,group,(uint)group.Length))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            if(!EndUpdateResource(update,false)) throw new Win32Exception(Marshal.GetLastWin32Error());
            update=IntPtr.Zero;
        }
        finally { if(update!=IntPtr.Zero) EndUpdateResource(update,true); }
    }

    private static byte[] ResourceBytes(IntPtr module,int type,int name)
    {
        IntPtr found=FindResource(module,new IntPtr(name),new IntPtr(type));
        if(found==IntPtr.Zero) throw new InvalidDataException("Expected embedded icon resource not found.");
        int size=checked((int)SizeofResource(module,found));
        IntPtr loaded=LoadResource(module,found), pointer=LockResource(loaded);
        if(pointer==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        byte[] data=new byte[size]; Marshal.Copy(pointer,data,0,size); return data;
    }

    public static int VerifyIcon(string executable,string iconPath)
    {
        // Data-file loading never resolves imports or executes an entry point.
        IntPtr module=LoadLibraryEx(executable,IntPtr.Zero,2);
        if(module==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            byte[] group=ResourceBytes(module,14,1), icon=File.ReadAllBytes(iconPath);
            int count=BitConverter.ToUInt16(icon,4);
            if(group.Length!=6+14*count || BitConverter.ToUInt16(group,4)!=count)
                throw new InvalidDataException("Embedded icon group does not match ICO directory.");
            for(int i=0;i<count;i++)
            {
                int entry=6+i*16;
                byte[] expected=new byte[(int)BitConverter.ToUInt32(icon,entry+8)];
                Array.Copy(icon,(int)BitConverter.ToUInt32(icon,entry+12),expected,0,expected.Length);
                byte[] actual=ResourceBytes(module,3,BitConverter.ToUInt16(group,6+i*14+12));
                if(Hash(expected)!=Hash(actual)) throw new InvalidDataException("Embedded icon PNG differs from approved ICO.");
            }
            return count;
        }
        finally { FreeLibrary(module); }
    }

    private static string Hash(byte[] bytes)
    {
        using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","");
    }

    public static Dictionary<string,string> NonResourceSections(string file)
    {
        using(var stream=File.OpenRead(file))
        using(var reader=new BinaryReader(stream))
        {
            if(stream.Length<64) throw new InvalidDataException("Invalid PE header.");
            stream.Position=0x3c; int pe=reader.ReadInt32();
            if(pe<0 || (long)pe+24>stream.Length) throw new InvalidDataException("Invalid PE header.");
            stream.Position=pe;
            if(reader.ReadUInt32()!=0x4550) throw new InvalidDataException("Invalid PE signature.");
            stream.Position=pe+6; int count=reader.ReadUInt16();
            stream.Position=pe+20; long table=pe+24+reader.ReadUInt16();
            var result=new Dictionary<string,string>();
            byte[] buffer=new byte[1024*1024];
            for(int i=0;i<count;i++)
            {
                long entry=table+i*40;
                if(entry+40>stream.Length) throw new InvalidDataException("Invalid PE section table.");
                stream.Position=entry;
                string name=Encoding.ASCII.GetString(reader.ReadBytes(8)).TrimEnd('\0');
                if(name==".rsrc") continue;
                stream.Position=entry+16; uint size=reader.ReadUInt32(), offset=reader.ReadUInt32();
                if((long)offset+size>stream.Length) throw new InvalidDataException("Invalid PE section range.");
                stream.Position=offset;
                using(var sha=SHA256.Create())
                {
                    long remaining=size;
                    while(remaining>0)
                    {
                        int read=stream.Read(buffer,0,(int)Math.Min(buffer.Length,remaining));
                        if(read==0) throw new EndOfStreamException();
                        sha.TransformBlock(buffer,0,read,buffer,0); remaining-=read;
                    }
                    sha.TransformFinalBlock(buffer,0,0);
                    result.Add(name,BitConverter.ToString(sha.Hash).Replace("-",""));
                }
            }
            return result;
        }
    }
}
