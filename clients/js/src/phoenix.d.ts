declare module "phoenix" {
  export class Socket {
    constructor(endPoint: string, opts?: object);
    connect(): void;
    disconnect(): void;
    channel(topic: string, params?: object): Channel;
    endPointURL(): string;
  }

  export class Channel {
    socket: Socket;
    state: string;
    joinPush: Push;
    join(): Push;
    leave(): void;
    push(event: string, payload: unknown): Push;
    on(event: string, callback: (payload: unknown) => void): void;
    onError(callback: () => void): void;
    onClose(callback: () => void): void;
  }

  export class Push {
    receive(status: string, callback: (response: unknown) => void): Push;
  }
}
