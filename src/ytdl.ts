import ytdl from "ytdl-core";
import fs from "fs";
import { Logger } from "./logger";
import { SFTPCreds } from "./sftp";
import Ffmpeg from "fluent-ffmpeg";
import ffmpegPath from "ffmpeg-static";
import { sftp } from ".";
import yts from "yt-search";

export default class Youtube extends Logger {

  constructor() {
    super("Youtube");
  }

  public static async createAudioFile(id: string, creds: SFTPCreds) {

    const client = await sftp.getServer(creds);

    const sftpStream = client.createWriteStream(`/plugins/radio/audio/${id}.pcm`);
    
    return new Promise<void>((resolve, reject) => {
      ytdl(`http://www.youtube.com/watch?v=${id}`, {
      filter: "audioonly",
    })
      .pipe(fs.createWriteStream("audio.wav"))
      .on("error", (err) => {
        throw err;
      })
      .on("finish", () => {
        console.log("Finished downloading audio file");
        Ffmpeg("audio.wav")
        .setFfmpegPath(ffmpegPath as string)
          .audioBitrate("2k")
          .audioCodec("pcm_s16le")
          .format("s16le")
          .audioFilters("asetrate=48000, pan=mono|c0=c0")
          .audioFrequency(48000)
          .output(sftpStream)
          .on("end", () => {
            console.log("audio file created");
            resolve();
          })
          .run();
      });
    })
  }

  public static async query(query: string) {
    const info = await yts.search({
      query,
      pages: 1,
      category: "music"
    });
    return info;
  }

}

