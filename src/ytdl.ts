import ytdl from "ytdl-core";
import fs from "fs";
import { Logger } from "./logger";
import { SFTPCreds } from "./sftp";
import Ffmpeg from "fluent-ffmpeg";
import ffmpegPath from "ffmpeg-static";
import { sftp } from ".";
import yts from "yt-search";

export default class Youtube extends Logger {

  public static inProgress: Map<string, boolean> = new Map();

  constructor() {
    super("Youtube");
  }

  public static async createAudioFile(id: string, creds: SFTPCreds, meta: yts.VideoSearchResult) {

    const client = await sftp.getServer(creds);

    if (await client.exists(`/plugins/radio/audio/${id}.pcm`)) {
      return;
    }

    const videoMetaFile = `${id}\r\n${meta.title}\r\n${meta.author.name}\r\n${meta.duration.seconds}`

    const sftpStream = client.createWriteStream(`/plugins/radio/audio/${id}.pcm`);

    Youtube.inProgress.set(id, true);

    return await new Promise<void>((resolve, reject) => {
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
            .on("start", (command) => {
              console.log("Spawned FFMPEG with command: " + command);
            })
            .on("error", (err) => {
              reject(err);
            })
            .run();
        })
    })
      .then(async () => {
        console.log("Writing meta file");
        await new Promise<void>((resolve, reject) => {
          const metaStream = client.createWriteStream(`/plugins/radio/audio/${id}.meta`);

          metaStream.write(videoMetaFile, (err) => {
            if (err) {
              reject(err);
            } else {
              resolve();
            }
          });
        })

        console.log("Meta file written");

        Youtube.inProgress.delete(id);
      }).catch((err) => {
        Youtube.inProgress.delete(id);
        client.delete(`/plugins/radio/audio/${id}.pcm`);
        client.delete(`/plugins/radio/audio/${id}.meta`);
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

  public static async getStatus(id: string) {
    return {
      done: !Youtube.inProgress.has(id),
    }
  }

}

