// Windows .NET Framework 4.x. One SoundPlayer worker; no networking or injection.
using System;
using System.IO;
using System.Media;
using System.Diagnostics;
using System.Threading;
using System.Globalization;
using System.Text;

class VoiceHost {
    static string root, runtime, session;
    static volatile bool busy;
    static SoundPlayer player;
    static Thread worker;
    static bool GameRunning() {
        foreach(var process in Process.GetProcessesByName("Test_C-Win64-Shipping")) {
            using(process) { try { if(!process.HasExited)return true; }catch{} }
        }
        return false;
    }
    static readonly object gate = new object();
    static string ReadShared(string path) {
        using(var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
        using(var reader=new StreamReader(stream))return reader.ReadToEnd();
    }
    static void Atomic(string path, string value) {
        string temp=path+".tmp";
        File.WriteAllText(temp,value,Encoding.ASCII);
        for(int i=0;;i++) {
            try { if(File.Exists(path)) File.Replace(temp,path,null); else File.Move(temp,path);return; }
            catch(IOException) { if(i>=20)throw;Thread.Sleep(5); }
        }
    }
    static void Ack(string seq,string state) {
        lock(gate) Atomic(Path.Combine(runtime,"status.txt"),session+"\n"+seq+"\n"+state+"\n");
    }
    static void Log(string value) {
        lock(gate) { try { File.AppendAllText(Path.Combine(runtime,"host.log"),DateTime.UtcNow.ToString("o")+" "+value+"\n"); } catch {} }
    }
    static byte[] Scale(byte[] wav,double volume) {
        if(wav.Length<44 || Encoding.ASCII.GetString(wav,0,4)!="RIFF") throw new Exception("Invalid WAV");
        int pos=12;bool pcm=false;
        while(pos+8<=wav.Length) {
            string id=Encoding.ASCII.GetString(wav,pos,4);int length=BitConverter.ToInt32(wav,pos+4);pos+=8;
            if(length<0 || (long)pos+length>wav.Length)throw new Exception("Invalid WAV chunk");
            if(id=="fmt ")pcm=length>=16 && BitConverter.ToInt16(wav,pos)==1 && BitConverter.ToInt16(wav,pos+14)==16;
            if(id=="data") {
                if(!pcm)throw new Exception("PCM16 required");
                for(int j=pos;j+1<pos+length;j+=2) {
                    short sample=(short)(BitConverter.ToInt16(wav,j)*volume);
                    wav[j]=(byte)sample;wav[j+1]=(byte)(sample>>8);
                }
                return wav;
            }
            pos+=length+(length&1);
        }
        throw new Exception("Missing PCM data");
    }
    static void Stop() {
        try { if(player!=null) player.Stop(); } catch(ObjectDisposedException) {}
        if(worker!=null && worker.IsAlive)worker.Join(2000);
        if(worker!=null && worker.IsAlive)throw new Exception("Audio worker did not stop; channel remains locked");
    }
    static void Main(string[] args) {
        root=AppDomain.CurrentDomain.BaseDirectory;runtime=Path.Combine(root,"Runtime");
        Directory.CreateDirectory(runtime);
        using(var mutex=new Mutex(false,"Local\\IRR_RogueWarriorVoices_SingleChannel_v1")) {
            bool acquired=false;
            try { acquired=mutex.WaitOne(20000); } catch(AbandonedMutexException){acquired=true;}
            if(!acquired)return;
            try { Run(args); } catch(Exception e){Log("FATAL "+e.Message);} finally{Stop();mutex.ReleaseMutex();}
        }
    }
    static void Run(string[] args) {
        if(args.Length!=1)return;
        session=args[0];if(session.Length>80)return;
        string command=Path.Combine(runtime,"command.txt"),heartbeat=Path.Combine(runtime,"heartbeat.txt");
        string last="";DateTime started=DateTime.UtcNow;DateTime nextPulse=started;
        Ack("0","ready");Log("READY "+session);
        while(true) {
            // Game-thread callbacks pause during map loads. A live game process
            // keeps the host alive even when no heartbeat can be written.
            if((DateTime.UtcNow-started).TotalSeconds>15 && (!File.Exists(heartbeat) || (DateTime.UtcNow-File.GetLastWriteTimeUtc(heartbeat)).TotalSeconds>15) && !GameRunning())break;
            try {
                if(DateTime.UtcNow>=nextPulse) {
                    nextPulse=DateTime.UtcNow.AddSeconds(1);
                    long stamp=(long)(DateTime.UtcNow-new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;
                    Atomic(Path.Combine(runtime,"alive.txt"),session+"\n"+stamp+"\n");
                }
                if(File.Exists(heartbeat)) {
                    string owner=ReadShared(heartbeat).Trim();
                    if(owner.Length>0 && owner!=session)break;
                }
                if(File.Exists(command)) {
                    string content=ReadShared(command);
                    string[] p=content.Replace("\r","").Split('\n');
                    if(content!=last && p.Length>=5 && p[0]==session && p[4]=="END") {
                        last=content;
                        if(p[2]=="STOP") {Stop();Ack(p[1],"stopped");}
                        else if(!busy && (DateTime.UtcNow-File.GetLastWriteTimeUtc(command)).TotalSeconds<3) {
                            double volume;
                            if(!double.TryParse(p[3],NumberStyles.Float,CultureInfo.InvariantCulture,out volume) || volume<0 || volume>1)throw new Exception("Invalid volume");
                            string file=Path.GetFullPath(Path.Combine(root,p[2].Replace('/',Path.DirectorySeparatorChar)));
                            string audio=Path.GetFullPath(Path.Combine(root,"Audio"))+Path.DirectorySeparatorChar;
                            if(!file.StartsWith(audio,StringComparison.OrdinalIgnoreCase) || Path.GetExtension(file)!=".wav")throw new Exception("Invalid audio path");
                            byte[] data=Scale(File.ReadAllBytes(file),volume);string seq=p[1];
                            busy=true;Ack(seq,"playing");Log("START "+seq+" "+p[2]);
                            worker=new Thread(delegate(){
                                try {
                                    using(var stream=new MemoryStream(data))using(var sound=new SoundPlayer(stream)) {
                                        player=sound;sound.Load();sound.PlaySync();player=null;
                                    }
                                    Log("END "+seq);Ack(seq,"done");
                                }catch(Exception e){Log("ERROR "+seq+" "+e.Message);Ack(seq,"error");}
                                finally {player=null;busy=false;}
                            });
                            worker.IsBackground=true;worker.Start();
                        } else {Ack(p[1],"dropped");Log("DROP "+p[1]);}
                    }
                }
            }catch(IOException){}catch(Exception e){Log("ERROR "+e.Message);}
            Thread.Sleep(20);
        }
        Log("EXIT heartbeat expired");
    }
}
