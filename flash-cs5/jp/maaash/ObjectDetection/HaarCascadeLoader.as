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
	import flash.events.EventDispatcher;
	import flash.events.Event;
	import jp.maaash.net.ZipLoader;

	public class HaarCascadeLoader extends EventDispatcher {
		private var debug :Boolean = false;

		private var ziploader :ZipLoader = new ZipLoader;
		public  var cascade   :HaarCascade = new HaarCascade;
		public function HaarCascadeLoader( url :String ) {
			ziploader.url = url;
			ziploader.addEventListener(Event.COMPLETE,function(e:Event):void{
				logger("[Event.COMPLETE]e: "+e);
				ziploader.removeEventListener(Event.COMPLETE,arguments.callee);
				decodeHaarCascadeXML( new XML(ziploader.getContentAsString()) );
				dispatchEvent( new Event(Event.COMPLETE) );
			});
		}

		public function load():void{
			ziploader.load();
		}

		private function decodeHaarCascadeXML(x:XML):void{
			//logger("[decodeHaarCascadeXML]x: ",x);
			var size:String = x.children()[0].size;
			cascade.base_window_w = size.split(" ")[0];
			cascade.base_window_h = size.split(" ")[1];

			var stages:XML = x.children()[0].stages[0];
			var stage_nums:int = stages._.length();
			logger("stage_nums: ",stage_nums);

			var stagexml     :XML;
			var treexml      :XML;
			var tree         :FeatureTree;
			var feature_nums :int;
			var featurexml   :XML;
			var rects        :XML;
			var rectnums     :int;
			var rect1        :HaarRect;
			var rect2        :HaarRect;
			var rect3        :HaarRect;
			var feature      :FeatureBase;
			for( var i:int=0; i<stage_nums; i++ ){	// trees
				stagexml = stages._[i];
				treexml  = stagexml.trees[0];
				tree     = new FeatureTree;
				tree.stage_threshold = stagexml.stage_threshold[0];
				feature_nums = treexml._.length();
				logger("feature_nums: ",feature_nums);
				for( var j:int=0; j<feature_nums; j++ ){
					featurexml = treexml._[j]._[0];
					rects      = featurexml.feature[0].rects[0];
					rectnums   = rects._.length();
					rect1      = new HaarRect(rects._[0]);
					rect2      = new HaarRect(rects._[1]);
					switch(rectnums){
					case 2:
						feature = new Feature2Rects(featurexml.tilted,featurexml.threshold[0],featurexml.left_val[0],featurexml.right_val[0]);
						feature.setRect(rect1,0);
						feature.setRect(rect2,1);
						break;
					case 3:
						feature = new Feature3Rects(featurexml.tilted,featurexml.threshold[0],featurexml.left_val[0],featurexml.right_val[0]);
						feature.setRect(rect1,0);
						feature.setRect(rect2,1);
						rect3 = new HaarRect(rects._[2]);
						feature.setRect(rect3,2);
						break;
					}
					tree.features.push(feature);
				}
				cascade.trees.push(tree);
			}
			logger("trees: ",cascade.trees);
		}

		private function logger(... args):void{
			if(!debug){ return; }
			log(["[HaarCascadeLoader]"+args.shift()].concat(args));
		}
	}
}
