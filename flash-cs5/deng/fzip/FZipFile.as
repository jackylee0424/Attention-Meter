/*
 * Copyright (C) 2006 Claus Wahlers and Max Herkender
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

package deng.fzip
{
	import deng.utils.ChecksumUtil;
	
	import flash.utils.*;

	/**
	 * Represents a file contained in a ZIP archive.
	 */		
	public class FZipFile
	{
		private var _versionHost:int = 0;
		private var _versionNumber:String = "2.0";
		private var _compressionMethod:int = 8;
		private var _encrypted:Boolean = false;
		private var _implodeDictSize:int = -1;
		private var _implodeShannonFanoTrees:int = -1;
		private var _deflateSpeedOption:int = -1;
		private var _hasDataDescriptor:Boolean = false;
		private var _hasCompressedPatchedData:Boolean = false;
		private var _date:Date;
		private var _crc32:uint;
		private var _adler32:uint;
		private var _hasAdler32:Boolean = false;
		private var _sizeCompressed:uint = 0;
		private var _sizeUncompressed:uint = 0;
		private var _sizeFilename:uint = 0;
		private var _sizeExtra:uint = 0;
		private var _filename:String = "";
		private var _filenameEncoding:String;
		private var _extraFields:Dictionary;
		private var _comment:String = "";
		private var _content:ByteArray;

		private var isCompressed:Boolean = false;
		private var parseFunc:Function = parseFileHead;

		// compression methods
		/**
		 * @private
		 */		
		public static const COMPRESSION_NONE:int = 0;
		/**
		 * @private
		 */		
		public static const COMPRESSION_SHRUNK:int = 1;
		/**
		 * @private
		 */		
		public static const COMPRESSION_REDUCED_1:int = 2;
		/**
		 * @private
		 */		
		public static const COMPRESSION_REDUCED_2:int = 3;
		/**
		 * @private
		 */		
		public static const COMPRESSION_REDUCED_3:int = 4;
		/**
		 * @private
		 */		
		public static const COMPRESSION_REDUCED_4:int = 5;
		/**
		 * @private
		 */		
		public static const COMPRESSION_IMPLODED:int = 6;
		/**
		 * @private
		 */		
		public static const COMPRESSION_TOKENIZED:int = 7;
		/**
		 * @private
		 */		
		public static const COMPRESSION_DEFLATED:int = 8;
		/**
		 * @private
		 */		
		public static const COMPRESSION_DEFLATED_EXT:int = 9;
		/**
		 * @private
		 */		
		public static const COMPRESSION_IMPLODED_PKWARE:int = 10;

		/**
		 * @private
		 */		
		private static var HAS_INFLATE:Boolean = describeType(ByteArray).factory.method.(@name == "uncompress").hasComplexContent();
		
		/**
		 * Constructor
		 */		
		public function FZipFile(filenameEncoding:String = "utf-8") {
			_filenameEncoding = filenameEncoding;
			_extraFields = new Dictionary();
			_content = new ByteArray();
			_content.endian = Endian.BIG_ENDIAN;
		}
		
		/**
		 * The Date and time the file was created.
		 */
		public function get date():Date {
			return _date;
		}
		public function set date(value:Date):void {
			_date = (value != null) ? value : new Date();
		}
		
		/**
		 * The file name (including relative path).
		 */
		public function get filename():String {
			return _filename;
		}
		public function set filename(value:String):void {
			_filename = value;
		}
		
		/**
		 * The raw, uncompressed file. 
		 */
		public function get content():ByteArray {
			if(isCompressed) {
				uncompress();
			}
			return _content;
		}
		public function set content(data:ByteArray):void {
			if(data != null && data.length > 0) {
				data.position = 0;
				data.readBytes(_content, 0, data.length);
				_crc32 = ChecksumUtil.CRC32(_content);
				_hasAdler32 = false;
			} else {
				_content.length = 0;
				_content.position = 0;
				isCompressed = false;
			}
			compress();
		}
		
		/**
		 * The ZIP specification version supported by the software 
		 * used to encode the file.
		 */
		public function get versionNumber():String {
			return _versionNumber;
		}
		
		/**
		 * The size of the compressed file (in bytes).
		 */
		public function get sizeCompressed():uint {
			return _sizeCompressed;
		}
		
		/**
		 * The size of the uncompressed file (in bytes).
		 */
		public function get sizeUncompressed():uint {
			return _sizeUncompressed;
		}
		
		/**
		 * Gets the files content as string.
		 * 
		 * @param recompress If <code>true</code>, the raw file content
		 * is recompressed after decoding the string.
		 * 
		 * @param charset The character set used for decoding.
		 * 
		 * @return The file as string.
		 */
		public function getContentAsString(recompress:Boolean = true, charset:String = "utf-8"):String {
			if(isCompressed) {
				uncompress();
			}
			_content.position = 0;
			var str:String;
			// Is readMultiByte completely trustworthy with utf-8?
			// For now, readUTFBytes will take over.
			if(charset == "utf-8") {
				str = _content.readUTFBytes(_content.bytesAvailable);
			} else {
				str = _content.readMultiByte(_content.bytesAvailable, charset);
			}
			_content.position = 0;
			if(recompress) {
				compress();
			}
			return str;
		}

		/**
		 * Sets a string as the file's content.
		 * 
		 * @param value The string.
		 * @param charset The character set used for decoding.
		 */
		public function setContentAsString(value:String, charset:String = "utf-8"):void {
			_content.length = 0;
			_content.position = 0;
			isCompressed = false;
			if(value != null && value.length > 0) {
				if(charset == "utf-8") {
					_content.writeUTFBytes(value);
				} else {
					_content.writeMultiByte(value, charset);
				}
				_crc32 = ChecksumUtil.CRC32(_content);
				_hasAdler32 = false;
			}
			compress();
		}

		/**
		 * Serializes this zip archive into an IDataOutput stream (such as 
		 * ByteArray or FileStream) according to PKZIP APPNOTE.TXT
		 * 
		 * @param stream The stream to serialize the zip archive into.
		 * @param includeAdler32 If set to true, include Adler32 checksum.
		 * @param centralDir If set to true, serialize a central directory entry
		 * @param centralDirOffset Relative offset of local header (for central directory only).
		 * 
		 * @return The serialized zip file.
		 */
		public function serialize(stream:IDataOutput, includeAdler32:Boolean, centralDir:Boolean = false, centralDirOffset:uint = 0):uint {
			if(stream == null) { return 0; }
			if(centralDir) {
				// Write central directory file header signature
				stream.writeUnsignedInt(0x02014b50);
				// Write "version made by" host (usually 0) and number (always 2.0)
				stream.writeShort((_versionHost << 8) | 0x14);
			} else {
				// Write local file header signature
				stream.writeUnsignedInt(0x04034b50);
			}
			// Write "version needed to extract" host (usually 0) and number (always 2.0)
			stream.writeShort((_versionHost << 8) | 0x14);
			// Write the general purpose flag
			// - no encryption
			// - normal deflate
			// - no data descriptors
			// - no compressed patched data
			// - unicode as specified in _filenameEncoding 
			stream.writeShort((_filenameEncoding == "utf-8") ? 0x0800 : 0);
			// Write compression method (always deflate)
			stream.writeShort(COMPRESSION_DEFLATED);
			// Write date
			var d:Date = (_date != null) ? _date : new Date();
			var msdosTime:uint = uint(d.getSeconds()) | (uint(d.getMinutes()) << 5) | (uint(d.getHours()) << 11);
			var msdosDate:uint = uint(d.getDate()) | (uint(d.getMonth() + 1) << 5) | (uint(d.getFullYear() - 1980) << 9);
			stream.writeShort(msdosTime);
			stream.writeShort(msdosDate);
			// Write CRC32
			stream.writeUnsignedInt(_crc32);
			// Write compressed size
			stream.writeUnsignedInt(_sizeCompressed);
			// Write uncompressed size
			stream.writeUnsignedInt(_sizeUncompressed);
			// Prep filename
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			if (_filenameEncoding == "utf-8") {
				ba.writeUTFBytes(_filename);
			} else {
				ba.writeMultiByte(_filename, _filenameEncoding);
			}
			var filenameSize:uint = ba.position;
			// Prep extra fields
			for(var headerId:Object in _extraFields) {
				var extraBytes:ByteArray = _extraFields[headerId] as ByteArray;
				if(extraBytes != null) {
					ba.writeShort(uint(headerId));
					ba.writeShort(uint(extraBytes.length));
					ba.writeBytes(extraBytes);
				}
			}
			if (includeAdler32) {
				if (!_hasAdler32) {
					var compressed:Boolean = isCompressed;
					if (compressed) { uncompress(); }
					_adler32 = ChecksumUtil.Adler32(_content, 0, _content.length);
					_hasAdler32 = true;
					if (compressed) { compress(); }
				}
				ba.writeShort(0xdada);
				ba.writeShort(4);
				ba.writeUnsignedInt(_adler32);
			}
			var extrafieldsSize:uint = ba.position - filenameSize;
			// Prep comment (currently unused)
			if(centralDir && _comment.length > 0) {
				if (_filenameEncoding == "utf-8") {
					ba.writeUTFBytes(_comment);
				} else {
					ba.writeMultiByte(_comment, _filenameEncoding);
				}
			}
			var commentSize:uint = ba.position - filenameSize - extrafieldsSize;
			// Write filename and extra field sizes
			stream.writeShort(filenameSize);
			stream.writeShort(extrafieldsSize);
			if(centralDir) {
				// Write comment size
				stream.writeShort(commentSize);
				// Write disk number start (always 0)
				stream.writeShort(0);
				// Write file attributes (always 0)
				stream.writeShort(0);
				stream.writeUnsignedInt(0);
				// Write relative offset of local header
				stream.writeUnsignedInt(centralDirOffset);
			}
			// Write filename, extra field and comment
			if(filenameSize + extrafieldsSize + commentSize > 0) {
				stream.writeBytes(ba);
			}
			// Write file
			var fileSize:uint = 0;
			if(!centralDir && _sizeCompressed > 0) {
				if(HAS_INFLATE) {
					fileSize = _content.length;
					stream.writeBytes(_content, 0, fileSize);
				} else {
					fileSize = _content.length - 6;
					stream.writeBytes(_content, 2, fileSize);
				}
			}
			var size:uint = 30 + filenameSize + extrafieldsSize + commentSize + fileSize;
			if(centralDir) {
				size += 16;
			}
			return size;
		} 


		/**
		 * @private
		 */		
		internal function parse(stream:IDataInput):Boolean {
			while (stream.bytesAvailable && parseFunc(stream));
			return (parseFunc === parseFileIdle);
		}

		/**
		 * @private
		 */		
		private function parseFileIdle(stream:IDataInput):Boolean {
			return false;
		}

		/**
		 * @private
		 */		
		private function parseFileHead(stream:IDataInput):Boolean {
			if(stream.bytesAvailable >= 30) {
				parseHead(stream);
				if(_sizeFilename + _sizeExtra > 0) {
					parseFunc = parseFileHeadExt;
				} else {
					parseFunc = parseFileContent;
				}
				return true;
			}
			return false;
		}

		/**
		 * @private
		 */		
		private function parseFileHeadExt(stream:IDataInput):Boolean {
			if(stream.bytesAvailable >= _sizeFilename + _sizeExtra) {
				parseHeadExt(stream);
				parseFunc = parseFileContent;
				return true;
			}
			return false;
		}
		
		/**
		 * @private
		 */		
		private function parseFileContent(stream:IDataInput):Boolean {
			if(_hasDataDescriptor) {
				// Data descriptors are not supported
				parseFunc = parseFileIdle;
				throw new Error("Data descriptors are not supported.");
			} else if(_sizeCompressed == 0) {
				// This entry has no file attached
				parseFunc = parseFileIdle;
			} else if(stream.bytesAvailable >= _sizeCompressed) {
				parseContent(stream);
				parseFunc = parseFileIdle;
			} else {
				return false;
			}
			return true;
		}

		/**
		 * @private
		 */		
		protected function parseHead(data:IDataInput):void {
			var vSrc:uint = data.readUnsignedShort();
			_versionHost = vSrc >> 8;
			_versionNumber = Math.floor((vSrc & 0xff) / 10) + "." + ((vSrc & 0xff) % 10);
			var flag:uint = data.readUnsignedShort();
			_compressionMethod = data.readUnsignedShort();
			_encrypted = (flag & 0x01) !== 0;
			_hasDataDescriptor = (flag & 0x08) !== 0;
			_hasCompressedPatchedData = (flag & 0x20) !== 0;
			if ((flag & 800) !== 0) {
				_filenameEncoding = "utf-8";
			}
			if(_compressionMethod === COMPRESSION_IMPLODED) {
				_implodeDictSize = (flag & 0x02) !== 0 ? 8192 : 4096;
				_implodeShannonFanoTrees = (flag & 0x04) !== 0 ? 3 : 2;
			} else if(_compressionMethod === COMPRESSION_DEFLATED) {
				_deflateSpeedOption = (flag & 0x06) >> 1;
			}
			var msdosTime:uint = data.readUnsignedShort();
			var msdosDate:uint = data.readUnsignedShort();
			var sec:int = (msdosTime & 0x001f);
			var min:int = (msdosTime & 0x07e0) >> 5;
			var hour:int = (msdosTime & 0xf800) >> 11;
			var day:int = (msdosDate & 0x001f);
			var month:int = (msdosDate & 0x01e0) >> 5;
			var year:int = ((msdosDate & 0xfe00) >> 9) + 1980;
			_date = new Date(year, month - 1, day, hour, min, sec, 0);
			_crc32 = data.readUnsignedInt();
			_sizeCompressed = data.readUnsignedInt();
			_sizeUncompressed = data.readUnsignedInt();
			_sizeFilename = data.readUnsignedShort();
			_sizeExtra = data.readUnsignedShort();
		}
		
		/**
		 * @private
		 */		
		protected function parseHeadExt(data:IDataInput):void {
			if (_filenameEncoding == "utf-8") {
				_filename = data.readUTFBytes(_sizeFilename);// Fixes a bug in some players
			} else {
				_filename = data.readMultiByte(_sizeFilename, _filenameEncoding);
			}
			var bytesLeft:uint = _sizeExtra;
			while(bytesLeft > 4) {
				var headerId:uint = data.readUnsignedShort();
				var dataSize:uint = data.readUnsignedShort();
				if(dataSize > bytesLeft) {
					throw new Error("Parse error in file " + _filename + ": Extra field data size too big.");
				}
				if(headerId === 0xdada && dataSize === 4) {
					_adler32 = data.readUnsignedInt();
					_hasAdler32 = true;
				} else if(dataSize > 0) {
					var extraBytes:ByteArray = new ByteArray();
					data.readBytes(extraBytes, 0, dataSize);
					_extraFields[headerId] = extraBytes;
				}
				bytesLeft -= dataSize + 4;
			}
			if(bytesLeft > 0) {
				data.readBytes(new ByteArray(), 0, bytesLeft);
			}
		}

		/**
		 * @private
		 */		
		protected function parseContent(data:IDataInput):void {
			if(_compressionMethod === COMPRESSION_DEFLATED && !_encrypted) {
				if(HAS_INFLATE) {
					// Adobe Air supports inflate decompression.
					// If we got here, this is an Air application
					// and we can decompress without using the Adler32 hack
					// so we just write out the raw deflate compressed file
					data.readBytes(_content, 0, _sizeCompressed);
				} else if(_hasAdler32) {
					// Add zlib header
					// CMF (compression method and info)
					_content.writeByte(0x78);
					// FLG (compression level, preset dict, checkbits)
					var flg:uint = (~_deflateSpeedOption << 6) & 0xc0;
					flg += 31 - (((0x78 << 8) | flg) % 31);
					_content.writeByte(flg);
					// Add raw deflate-compressed file
					data.readBytes(_content, 2, _sizeCompressed);
					// Add adler32 checksum
					_content.position = _content.length;
					_content.writeUnsignedInt(_adler32);
				} else {
					throw new Error("Adler32 checksum not found.");
				}
				isCompressed = true;
			} else if(_compressionMethod == COMPRESSION_NONE) {
				data.readBytes(_content, 0, _sizeCompressed);
				isCompressed = false;
			} else {
				throw new Error("Compression method " + _compressionMethod + " is not supported.");
			}
			_content.position = 0;
		}
		
		/**
		 * @private
		 */		
		protected function compress():void {
			if(!isCompressed) {
				if(_content.length > 0) {
					_content.position = 0;
					_sizeUncompressed = _content.length;
					if(HAS_INFLATE) {
						_content.compress.apply(_content, ["deflate"]);
						_sizeCompressed = _content.length;
					} else {
						_content.compress();
						_sizeCompressed = _content.length - 6;
					}
					_content.position = 0;
					isCompressed = true;
				} else {
					_sizeCompressed = 0;
					_sizeUncompressed = 0;
				}
			}
		}
		
		/**
		 * @private
		 */		
		protected function uncompress():void {
			if(isCompressed && _content.length > 0) {
				_content.position = 0;
				if(HAS_INFLATE) {
					_content.uncompress.apply(_content, ["deflate"]);
				} else {
					_content.uncompress();
				}
				_content.position = 0;
				isCompressed = false;
			}
		}
		
		/**
		 * Returns a string representation of the FZipFile object.
		 */		
		public function toString():String {
			return "[FZipFile]"
				+ "\n  name:" + _filename
				+ "\n  date:" + _date
				+ "\n  sizeCompressed:" + _sizeCompressed
				+ "\n  sizeUncompressed:" + _sizeUncompressed
				+ "\n  versionHost:" + _versionHost
				+ "\n  versionNumber:" + _versionNumber
				+ "\n  compressionMethod:" + _compressionMethod
				+ "\n  encrypted:" + _encrypted
				+ "\n  hasDataDescriptor:" + _hasDataDescriptor
				+ "\n  hasCompressedPatchedData:" + _hasCompressedPatchedData
				+ "\n  filenameEncoding:" + _filenameEncoding
				+ "\n  crc32:" + _crc32.toString(16)
				+ "\n  adler32:" + _adler32.toString(16);
		}
	}
}