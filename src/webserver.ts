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

    const info = await Youtube.query(body.query).catch((err) => {
        res.status(500).json({
            error: err.message,
        });
        return;
    });

    if (!info) {
        return;
    }

    const video = info.videos[0];

    res.json(video);
    
    await Youtube.createAudioFile(video.videoId, body.creds, video)
    
});

app.get('/status/:id', async (req, res) => {
    const id = req.params.id;

    const status = await Youtube.getStatus(id);

    res.json(status);
});

app.listen(3300, () => {
    console.log("Listening on port 3300");
});
