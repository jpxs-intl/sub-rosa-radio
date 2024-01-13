import express from 'express';
import { SFTPCreds } from './sftp';
import Youtube from './ytdl';

const app = express();
app.use(express.json());

app.post('/request', async (req, res) => {

    const body = req.body as {
        creds: SFTPCreds,
        query: string,
    }

if (!body.creds || !body.query) {
    res.status(400).json({
        error: "Invalid request body",
    });
    return;
}

    const info = await Youtube.query(body.query);
    const video = info.videos[0];
    
    await Youtube.createAudioFile(video.videoId, body.creds)
    
    res.json(video);
});

app.listen(3300, () => {
    console.log("Listening on port 3300");
});
