//
//  VisualEditor.swift
//  Signed
//
//  Created by Markus Moenig on 4/10/23.
//

import SwiftUI
import MetalKit

public class VisualEditor
{
    let model               : Model
    
    var rect                = MMRect()
    var shapeMap            : [UUID: MMRect] = [:]
    
    init(model: Model) {
        self.model = model
    }
    
    func drawLine(drawables: MetalDrawables, line: Line) {
        
        let frameWidth = Float(drawables.metalView.frame.width)
        //let frameHeight = Float(drawables.metalView.frame.height)
        
        let width : Float = 400
        let height : Float = 30
        let left = frameWidth / 2 - width / 2
        let top : Float = 60
        
        rect = MMRect(left, top, width, height)
        
        drawables.drawBox(position: float2(left-1, top-1), size: float2(width+2, height+2), rounding: 2, borderSize: 2, onion: 0, fillColor: float4(0,0,0,0), borderColor: float4(0.2, 0.2, 0.2, 1))
        
        shapeMap = [:]
        
        for shape in line.shapes?.allObjects as! [Shape] {
            
            let offset = ((shape.lineOffset) / 2.0) + 0.5// + shape.lineSize / 2
            let shapeSize = shape.lineSize * width / 2.0
            
            let x = left + offset * width
            let w = shapeSize
                        
            shapeMap[shape.id!] = MMRect(x, top, w, height)
            
            var color = float3(repeating: 0.5)
            if let material = model.getMaterial(shape.material) {
                color.x = material.red
                color.y = material.green
                color.z = material.blue
            }
            
            drawables.drawBox(position: float2(x, top), size: float2(w, height), rounding: 0, borderSize: 0, onion: 0, fillColor: float4(color.x, color.y, color.z,1))

        }
    }
    
    func mouseDown(pos: float2) -> Bool {

        if rect.contains(pos.x, pos.y) {
            
            for (id, rect) in self.shapeMap {
                if rect.contains(pos.x, pos.y) {
                    
                    if let line = model.currLine {
                        for shape in line.shapes?.allObjects as! [Shape] {
                            if shape.id == id {
                                model.shapeChanged.send(shape)
                                return true
                            }
                        }
                    }
                }
            }
            
            return true
        }
        
        model.shapeChanged.send(nil)

        return false
    }
}
