import sftp from "ssh2-sftp-client";
import { Logger } from "./logger";

export interface SFTPCreds {
    host: string,
    port: number,
    serverId: string,
    username: string,
    password: string,
}

export default class SFTP extends Logger {

    private _clients: Map<string, sftp> = new Map();

    constructor() {
        super("SFTP");
    }

    public async connectServer(creds:SFTPCreds) {

        const client = new sftp();

        client.on("error", (err) => {
            this.error(`Error on server ${creds.serverId}: ${err.message}`);
        })

        this.log(`Logging in to server | sftp://${creds.username}.${creds.serverId}:${creds.password}@${creds.host}:${creds.port}`);

        await client.connect({
            host: creds.host,
            port: creds.port,
            username: `${creds.username}.${creds.serverId}`,
            password: creds.password,
        });

        this._clients.set(creds.serverId, client);
        this.info(`Connected to server ${creds.serverId}`);

    }

    public async getServer(creds: SFTPCreds): Promise<sftp> {
        if (!this._clients.has(creds.serverId)) {
            await this.connectServer(creds);
        }
        return this._clients.get(creds.serverId) as sftp;
    }
}
