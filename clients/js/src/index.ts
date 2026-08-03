import { Channel, Socket } from "phoenix";
import * as Y from "yjs";
import { PhoenixChannelProvider } from "y-phoenix-channel";

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

export type YDocProviderOptions = {
  awareness?: import("y-protocols/awareness").Awareness;
  resyncInterval?: number;
  updateThrottle?: number;
  awarenessThrottle?: number;
};

export class Parlor {
  readonly socket: Socket;

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
    return new ParlorRoom(roomId, channel);
  }

  disconnect(): void {
    this.socket.disconnect();
  }
}

export class ParlorRoom {
  readonly roomId: string;
  readonly channel: Channel;
  private joined: Promise<void>;

  constructor(roomId: string, channel: Channel) {
    this.roomId = roomId;
    this.channel = channel;
    this.joined = new Promise((resolve, reject) => {
      channel
        .join()
        .receive("ok", () => resolve())
        .receive("error", (response: unknown) => reject(response));
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

  async connectYDoc(
    doc: Y.Doc = new Y.Doc(),
    options: YDocProviderOptions = {}
  ): Promise<PhoenixChannelProvider> {
    await this.joined;

    const provider = new PhoenixChannelProvider(
      this.channel.socket,
      `room:${this.roomId}`,
      doc,
      {
        channel: this.channel,
        connect: true,
        disableBc: true,
        ...options
      }
    );

    return provider;
  }

  onMessage(callback: (payload: Record<string, unknown>) => void): void {
    this.channel.on("msg", callback as (payload: unknown) => void);
  }

  onStateChange(
    callback: (patch: StatePatch | StateSync) => void
  ): void {
    this.channel.on("state:patch", callback as (payload: unknown) => void);
    this.channel.on("state:sync", callback as (payload: unknown) => void);
  }

  onPresence(
    callback: (payload: Record<string, unknown>) => void
  ): void {
    this.channel.on("presence_state", callback as (payload: unknown) => void);
    this.channel.on("presence_diff", callback as (payload: unknown) => void);
  }

  onEvent(event: string, callback: (payload: unknown) => void): void {
    this.channel.on(event, callback);
  }

  leave(): void {
    this.channel.leave();
  }
}

export { PhoenixChannelProvider };
export * as Y from "yjs";
