import { Channel, Socket } from "phoenix";

export type ParlorOptions = {
  url: string;
  token?: string;
  params?: Record<string, string>;
};

export type ParlorUserMeta = Record<string, unknown>;

export type StatePatch = {
  op: "set" | "delete";
  key: string;
  value?: unknown;
  state: Record<string, unknown>;
};

export type StateSync = {
  state: Record<string, unknown>;
};

export class Parlor {
  private socket: Socket;

  constructor(options: ParlorOptions) {
    const params = {
      ...(options.params ?? {}),
      ...(options.token ? { token: options.token } : {})
    };

    this.socket = new Socket(options.url, { params });
    this.socket.connect();
  }

  join(roomId: string): ParlorRoom {
    const channel = this.socket.channel(`room:${roomId}`, {});
    return new ParlorRoom(channel);
  }

  disconnect(): void {
    this.socket.disconnect();
  }
}

export class ParlorRoom {
  private channel: Channel;
  private joined: Promise<void>;

  constructor(channel: Channel) {
    this.channel = channel;
    this.joined = new Promise((resolve, reject) => {
      channel
        .join()
        .receive("ok", () => resolve())
        .receive("error", (response) => reject(response));
    });
  }

  async send(payload: Record<string, unknown>): Promise<void> {
    await this.joined;
    this.channel.push("msg", payload);
  }

  async setState(key: string, value: unknown): Promise<void> {
    await this.joined;
    this.channel.push("state:set", { key, value });
  }

  async deleteState(key: string): Promise<void> {
    await this.joined;
    this.channel.push("state:delete", { key });
  }

  onMessage(callback: (payload: Record<string, unknown>) => void): void {
    this.channel.on("msg", callback);
  }

  onStateChange(
    callback: (patch: StatePatch | StateSync) => void
  ): void {
    this.channel.on("state:patch", callback);
    this.channel.on("state:sync", callback);
  }

  onPresence(
    callback: (payload: Record<string, unknown>) => void
  ): void {
    this.channel.on("presence_state", callback);
    this.channel.on("presence_diff", callback);
  }

  onEvent(event: string, callback: (payload: unknown) => void): void {
    this.channel.on(event, callback);
  }

  leave(): void {
    this.channel.leave();
  }
}
