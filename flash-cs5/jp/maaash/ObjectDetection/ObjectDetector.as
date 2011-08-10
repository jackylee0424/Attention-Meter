//
// Project Marilena
// Object Detection in Actionscript3
// based on OpenCV (Open Computer Vision Library) Object Detection
//
// Copyright (C) 2008, Masakazu OHTSUKA (mash), all rights reserved.
// contact o.masakazu(at)gmail.com
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   * Redistribution's of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistribution's in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
// This software is provided by the copyright holders and contributors "as is" and
// any express or implied warranties, including, but not limited to, the implied
// warranties of merchantability and fitness for a particular purpose are disclaimed.
// In no event shall the Intel Corporation or contributors be liable for any direct,
// indirect, incidental, special, exemplary, or consequential damages
// (including, but not limited to, procurement of substitute goods or services;
// loss of use, data, or profits; or business interruption) however caused
// and on any theory of liability, whether in contract, strict liability,
// or tort (including negligence or otherwise) arising in any way out of
// the use of this software, even if advised of the possibility of such damage.
//
package jp.maaash.ObjectDetection
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.display.Bitmap;
	import flash.geom.Rectangle;
	import flash.utils.setTimeout;
	public class ObjectDetector extends EventDispatcher{
		private var debug     :Boolean = false;
		private var tgt       :TargetImage;
		public  var detected  :Array;	// of Rectangles
		public  var cascade   :HaarCascade;
		private var _options  :ObjectDetectorOptions;
		private var xmlloader :HaarCascadeLoader;

		private var waiting   :Boolean = false;
		private var loaded    :Boolean = false;

		public function ObjectDetector() {
			tgt = new TargetImage;
		}

		public function detect( bmp :Bitmap = null ) :void{
			logger("[detect]");
			if ( bmp && bmp.bitmapData ) {
				tgt.bitmapData = bmp.bitmapData;
			}

			if ( !loaded ) {
				waiting = true;
				return;
			}
			dispatchEvent( new ObjectDetectorEvent(ObjectDetectorEvent.DETECTION_START) );
			_detect();
		}

		private function _detect() :void {

			detected = new Array;
			var imgw :int = tgt.width, imgh :int = tgt.height;
			var scaledw :int, scaledh :int, limitx  :int, limity  :int, stepx :int, stepy :int, result :int, factor:Number = 1;
			for( factor = 1;
				factor*cascade.base_window_w < imgw && factor*cascade.base_window_h < imgh;
				factor *= _options.scale_factor )
			{
				scaledw = int( cascade.base_window_w * factor );
				scaledh = int( cascade.base_window_h * factor );
				if( scaledw < _options.min_size || scaledh < _options.min_size ){
					continue;
				}
				limitx = tgt.width  - scaledw;
				limity = tgt.height - scaledh;
				if( _options.endx != ObjectDetectorOptions.INVALID_POS && _options.endy != ObjectDetectorOptions.INVALID_POS ){
					limitx = Math.min( _options.endx, limitx );
					limity = Math.min( _options.endy, limity );
				}
				logger("[detect]limitx,y: "+limitx+","+limity);

				//stepx  = Math.max(_options.MIN_MARGIN_SEARCH,factor);
				stepx  = scaledw>>3;
				stepy  = stepx;
				logger("[detect] w,h,step: "+scaledw+","+scaledh+","+stepx);

				var ix:int=0, iy:int=0, startx:int=0, starty:int=0;
				if( _options.startx != ObjectDetectorOptions.INVALID_POS && _options.starty != ObjectDetectorOptions.INVALID_POS ){
					startx = Math.max( ix, _options.startx );
					starty = Math.max( iy, _options.starty );
				}
				logger("[detect]startx,y: "+startx+","+starty);

				for(     iy = starty; iy < limity; iy += stepy ){
					for( ix = startx; ix < limitx; ix += stepx ){
						if( _options.search_mode & ObjectDetectorOptions.SEARCH_MODE_NO_OVERLAP &&
							overlaps(ix,iy,scaledw,scaledh) ){
							// do nothing
						}else{
							//logger("[checkAndRun]ix,iy,scaledw,scaledh: "+ix+","+iy+","+scaledw+","+scaledh);
							cascade.scale = factor;
							result = runHaarClassifierCascade(cascade,ix,iy,scaledw,scaledh);
							if ( result > 0 ) {
								var faceArea :Rectangle = new Rectangle(ix,iy,scaledw,scaledh);
								detected.push( faceArea );
								logger("[createCheckAndRun]found!: "+ix+","+iy+","+scaledw+","+scaledh);

								// doesnt mean anything cause detection is not time-divided (now)
								var ev1 :ObjectDetectorEvent = new ObjectDetectorEvent( ObjectDetectorEvent.FACE_FOUND );
								ev1.rect = faceArea;
								dispatchEvent( ev1 );
							}
						}
					}
				}
			}

			// integrate redundant candidates ...

			var ev2 :ObjectDetectorEvent = new ObjectDetectorEvent( ObjectDetectorEvent.DETECTION_COMPLETE );
			ev2.rects = detected;
			dispatchEvent( ev2 );
		}

		private function runHaarClassifierCascade(c:HaarCascade,x:int,y:int,w:int,h:int):int{
			//logger("[runHaarClassifierCascade] c:",c,x,y,w,h);
			var mean :Number                 = tgt.getSum(x,y,w,h) * c.inv_window_area;
			var variance_norm_factor :Number = tgt.getSum2(x,y,w,h)* c.inv_window_area - mean*mean;
			if( variance_norm_factor >= 0 ){
				variance_norm_factor = Math.sqrt(variance_norm_factor);
			}else{
				variance_norm_factor = 1;
			}

			var trees :Array = c.trees, treenums :int = trees.length, tree: FeatureTree, features :Array, featurenums :int, val :Number = 0, sum :Number = 0, feature :FeatureBase, i :int=0, j :int=0, st_th:Number = 0;
			for( i=0; i<treenums; i++ ){
				tree        = trees[i];
				features    = tree.features;
				featurenums = features.length;
				val         = 0;
				st_th       = tree.stage_threshold;
				for( j=0; j<featurenums; j++ ){
					feature = features[j];
					sum  = feature.getSum( tgt, x, y );

//					val += (sum < feature.threshold * variance_norm_factor) ?
//						feature.left_val : feature.right_val;
//
//					* Ternary operation causes coersion and makes slower. 

					if (sum < feature.threshold * variance_norm_factor)
						val += feature.left_val;
					else
						val += feature.right_val;

					if( val > st_th ){
						// left_val, right_val are always plus
						break;
					}
				}
				if( val < st_th ){
					return 0;
				}
			}
			return 1;
		}

		private function overlaps(_x:int,_y:int,_w:int,_h:int):Boolean{
			// if the area we're going to check contains, or overlaps the square which is already picked up, ignore it
			var i:int=0;
			var l:int=detected.length;
			var tg: Rectangle;
			var x:int = _x, y:int = _y, w:int = _w, h:int = _h, tx1:int, tx2:int, ty1:int, ty2:int;
			for( i=0; i<l; i++ ){
				tg = detected[i];
				tx1 = tg.x;
				tx2 = tg.x + tg.width;
				ty1 = tg.y;
				ty2 = tg.y + tg.height;
				if(  ( ( x <= tx1 && tx1 < x+w )
				     ||( x <= tx2 && tx2 < x+w ) )
				  && ( ( y <= ty1 && ty1 < y+h )
				     ||( y <= ty2 && ty2 < y+h ) )  )
				{
					return true;
				}
			}
			return false;
		}

		public function loadHaarCascades( url :String ) :void {
			xmlloader = new HaarCascadeLoader( url );
			xmlloader.addEventListener(Event.COMPLETE,function(e:Event):void{
				xmlloader.removeEventListener(Event.COMPLETE,arguments.callee);
				dispatchEvent( new ObjectDetectorEvent(ObjectDetectorEvent.HAARCASCADES_LOAD_COMPLETE) );
				cascade = xmlloader.cascade;

				loaded = true;
				if( waiting ){
					waiting = false;
					detect();
				}
			});
			loaded = false;
			dispatchEvent( new ObjectDetectorEvent(ObjectDetectorEvent.HAARCASCADES_LOADING) );
			xmlloader.load();	// kick it!
		}

		public function set bitmap( bmp :Bitmap ) :void {
			tgt.bitmapData = bmp.bitmapData;
		}
		public function set options( opt :ObjectDetectorOptions ) :void {
			_options = opt;
		}

		private function logger(... args):void{
			if(!debug){ return; }
			log(["[ObjectDetector]"+args.shift()].concat(args));
		}
	}
}
