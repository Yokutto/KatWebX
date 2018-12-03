#![allow(unused_variables)]
extern crate actix;
extern crate actix_web;
extern crate futures;

use trim_prefix;
use actix::*;
use actix_web::{actix::Actor, ws, ws::{Client, ClientWriter, Message, ProtocolError}};
use futures::Future;
use std::{thread, sync::mpsc::{Receiver, Sender, channel}, time::{Duration, Instant}};

struct WsClient(ClientWriter, Sender<String>);

#[derive(Message)]
struct ClientCommand(String);

impl Actor for WsClient {
    type Context = Context<Self>;

    fn started(&mut self, ctx: &mut Context<Self>) {
        self.hb(ctx)
    }

    fn stopped(&mut self, ctx: &mut Context<Self>) {
        ctx.stop();
    }
}

impl WsClient {
    fn hb(&self, ctx: &mut Context<Self>) {
        ctx.run_later(Duration::new(1, 0), |act, ctx| {
			act.0.ping("");
            act.hb(ctx);
        });
    }
}

impl Handler<ClientCommand> for WsClient {
    type Result = ();

    fn handle(&mut self, msg: ClientCommand, ctx: &mut Context<Self>) {
        self.0.text(msg.0)
    }
}

impl StreamHandler<Message, ProtocolError> for WsClient {
    fn handle(&mut self, msg: Message, ctx: &mut Context<Self>) {
		if let Message::Text(txt) = msg {let _ = self.1.send(txt);}
    }

    fn finished(&mut self, ctx: &mut Context<Self>) {
        ctx.stop()
    }
}

pub struct WsProxy {
	hb: Instant,
	send: Sender<String>,
	recv: Receiver<String>,
}

impl Actor for WsProxy {
	type Context = ws::WebsocketContext<Self>;
	fn started(&mut self, ctx: &mut Self::Context) {
		self.hb(ctx);
		self.hc(ctx);
	}
}

impl WsProxy {
	pub fn new(path: &str) -> Self {
		let (sender1, receiver1) = channel();
		let (sender2, receiver2) = channel();

		Arbiter::spawn(
			Client::new(["ws", trim_prefix("http", path)].concat())
				.connect()
				.map_err(|e| {println!("{:?}", e)})
				.map(|(reader, writer)| {
					let addr = WsClient::create(|ctx| {
						WsClient::add_stream(reader, ctx);
						WsClient(writer, sender2)
					});
					thread::spawn(move || {
						for cmd in receiver1.iter() {
							addr.do_send(ClientCommand(cmd));
						};
					});
				}),
		);

		Self {
			hb: Instant::now(),
			send: sender1,
			recv: receiver2,
		}
	}

	fn hb(&self, ctx: &mut <Self as Actor>::Context) {
		ctx.run_interval(Duration::from_secs(5), |act, ctx| {
			if Instant::now().duration_since(act.hb) > Duration::from_secs(20) {
				ctx.stop();
				return;
			}
			ctx.ping("");
		});
	}
	fn hc(&self, ctx: &mut <Self as Actor>::Context) {
		ctx.run_interval(Duration::from_millis(250), |act, ctx| {
			for msg in act.recv.try_iter() {
				ctx.text(msg);
			};
		});
	}
}

impl StreamHandler<ws::Message, ws::ProtocolError> for WsProxy {
	fn handle(&mut self, msg: ws::Message, ctx: &mut Self::Context) {
        match msg {
            Message::Ping(msg) => {
                self.hb = Instant::now();
                ctx.pong(&msg);
            }
            Message::Pong(_) => {
                self.hb = Instant::now();
            }
            Message::Text(text) => {let _ = self.send.send(text);},
            Message::Binary(bin) => (),
            Message::Close(_) => {
                ctx.stop();
            }
        }
    }
}
