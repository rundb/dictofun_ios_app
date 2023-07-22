//
//  Adpcm.swift
//  dictofun_ios_app
//
//  Created by Roman on 21.07.23.
//

import Foundation
import AVFoundation

let index_table: [Int8] = [
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
]

let stepsizeTable: [Int16] = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
]


func decodeAdpcm(from data: Data) -> Data {
    var valpred: Int32 = 0
    var delta: Int32 = 0
    var index: Int32 = 0
    
    var output: Data = Data([])
    var step: Int16 = stepsizeTable[Int(index)]
    
    var bufferstep: Int32 = 0
    var inputbuffer: Int32 = 0
    var inSize = data.count
    inSize = (inSize - 3) * 2
    
    var i = 0
    
    while inSize > 0 {
        // Step 1: get the delta value
        if bufferstep > 0 {
            delta = inputbuffer & 0xF
        }
        else {
            inputbuffer = Int32(UInt8(data[i]))
            delta = (inputbuffer >> 4) & 0xF
            i += 1
        }
        bufferstep = (bufferstep == 0) ? 1 : 0
        
        // Step 2: find the new index value
        index += Int32(index_table[Int(delta)])
        if index < 0 {
            index = 0
        }
        if index > 88 {
            index = 88
        }
        
        // Step 3: separate sign and magnitude
        let sign = delta & 8
        delta = delta & 7
        
        // Step 4: compute difference and new predicted value
        var vpdiff = Int32(step) >> 3
        if delta & 4 > 0 {
            vpdiff += Int32(step)
        }
        if delta & 2 > 0 {
            vpdiff += (Int32(step) >> 1)
        }
        if delta & 1 > 0 {
            vpdiff += (Int32(step) >> 2)
        }
        if sign > 0 {
            valpred -= Int32(vpdiff)
        }
        else {
            valpred += Int32(vpdiff)
        }
        
        // Step 5: clamp output value
        if valpred > 32768 {
            valpred = 32768
        }
        else if valpred < -32768 {
            valpred = -32768
        }
        
        // Step 6: update step value
        step = stepsizeTable[Int(index)]
        
        // Step 7.
        var nextByte0: UInt8 = UInt8(valpred & 0xff)
        var nextByte1: UInt8 = UInt8((valpred>>8) & 0xff)
        
        output.append(&nextByte0, count: 1)
        output.append(&nextByte1, count: 1)
        
        inSize -= 1
    }
    
    return output
}

func pcmToWav(with data: Data, andFrequency frequency: Int) -> AVAudioFile? {
    var output = Data([])
    
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000.0, channels: 1, interleaved: false)
    
    
    return nil
}
