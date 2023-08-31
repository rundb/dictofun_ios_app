//
//  Wav.swift
//  dictofun_ios_app
//
//  Created by Roman on 31.08.23.
//

import Foundation

func intToByteArray(_ i: Int32) -> [UInt8] {
      return [
        //little endian
        UInt8(truncatingIfNeeded: (i      ) & 0xff),
        UInt8(truncatingIfNeeded: (i >>  8) & 0xff),
        UInt8(truncatingIfNeeded: (i >> 16) & 0xff),
        UInt8(truncatingIfNeeded: (i >> 24) & 0xff)
       ]
 }

func shortToByteArray(_ i: Int16) -> [UInt8] {
       return [
           //little endian
           UInt8(truncatingIfNeeded: (i      ) & 0xff),
           UInt8(truncatingIfNeeded: (i >>  8) & 0xff)
       ]
 }

func createWaveFile(data: Data) -> Data {
     let sampleRate:Int32 = 16000
     let chunkSize:Int32 = 36 + Int32(data.count)
     let subChunkSize:Int32 = 16
     let format:Int16 = 1
     let channels:Int16 = 1
     let bitsPerSample:Int16 = 16
     let byteRate:Int32 = sampleRate * Int32(channels * bitsPerSample / 8)
     let blockAlign: Int16 = channels * bitsPerSample / 8
     let dataSize:Int32 = Int32(data.count)

     var header = Data([])

     header.append([UInt8]("RIFF".utf8), count: 4)
     header.append(intToByteArray(chunkSize), count: 4)

     //WAVE
     header.append([UInt8]("WAVE".utf8), count: 4)

     //FMT
     header.append([UInt8]("fmt ".utf8), count: 4)

     header.append(intToByteArray(subChunkSize), count: 4)
     header.append(shortToByteArray(format), count: 2)
     header.append(shortToByteArray(channels), count: 2)
     header.append(intToByteArray(sampleRate), count: 4)
     header.append(intToByteArray(byteRate), count: 4)
     header.append(shortToByteArray(blockAlign), count: 2)
     header.append(shortToByteArray(bitsPerSample), count: 2)

     header.append([UInt8]("data".utf8), count: 4)
     header.append(intToByteArray(dataSize), count: 4)

     return header + data
}
