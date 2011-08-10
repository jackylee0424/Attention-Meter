package jp.maaash.net {
	import flash.events.EventDispatcher;
	import flash.events.Event;
	import flash.net.URLRequest;
	import deng.fzip.*;

	public class ZipLoader extends EventDispatcher{
		private var debug :Boolean;
		private var _url  :String;
		private var req   :URLRequest;
		private var zip   :FZip;
		public  var file  :FZipFile;

		public function ZipLoader(d:Boolean=false){
			debug = d;

			req = new URLRequest;

			zip = new FZip;
			zip.addEventListener( Event.COMPLETE, function(e:Event):void{
				zip.removeEventListener( Event.COMPLETE, arguments.callee );
				file = zip.getFileAt(0);
				dispatchEvent( e.clone() );
			});

		}

		public function load():void{
			zip.load(req);
		}

		public function set url(u:String):void{
			_url = u;
			req.url = _url;
		}

		public function getContentAsString():String{
			return file.getContentAsString();
		}

		private function logger(... args):void{
			if(!debug){ return; }
			log(["[ZipLoader]"+args.shift()].concat(args));
		}
	}
}
