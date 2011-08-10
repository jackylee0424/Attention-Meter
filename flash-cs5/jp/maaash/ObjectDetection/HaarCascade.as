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
	public class HaarCascade{
		public  var base_window_w   :int;
		public  var base_window_h   :int;
		public  var inv_window_area :Number;
		public  var trees           :Array = new Array;
		private var _scale          :Number = 0;

		public function HaarCascade() {
		}

		public function set scale(s:Number):void{
			if( s==_scale ){ return; }
			_scale = s;
			// update rect's width, height, weight
			var treenums :int = trees.length, tree :FeatureTree, featurenums :int, i:int=0, j:int=0;
			inv_window_area = 1/(base_window_w*base_window_h*s*s);
			for( i=0; i<treenums; i++ ){
				tree        = trees[i];
				featurenums = tree.features.length;
				for( j=0; j<featurenums; j++ ){
					tree.features[j].setScaleAndWeight( s, inv_window_area );
				}
			}
		}
	}
}
