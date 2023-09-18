//
//  Drawables.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import MetalKit

class MetalDrawables
{
    let metalView       : SMTKView
    
    let device          : MTLDevice
    let commandQueue    : MTLCommandQueue!
    
    var pipelineState   : MTLRenderPipelineState! = nil
    var pipelineStateDesc : MTLRenderPipelineDescriptor! = nil

    var renderEncoder   : MTLRenderCommandEncoder! = nil

    var vertexBuffer    : MTLBuffer? = nil
    var viewportSize    : vector_uint2
    
    var commandBuffer   : MTLCommandBuffer! = nil
    
    var discState       : MTLRenderPipelineState? = nil
    var boxState        : MTLRenderPipelineState? = nil

    var scaleFactor     : Float
    var viewSize        = float2(0,0)
    
    init(_ metalView: SMTKView)
    {
        self.metalView = metalView
        
        #if os(iOS)
        metalView.layer.isOpaque = false
        #else
        metalView.layer?.isOpaque = false
        #endif

        device = metalView.device!
        viewportSize = vector_uint2( UInt32(metalView.bounds.width), UInt32(metalView.bounds.height) )
        commandQueue = device.makeCommandQueue()
        
        #if os(OSX)
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
        #else
        scaleFactor = Float(UIScreen.main.scale)
        #endif
                
        if let defaultLibrary = device.makeDefaultLibrary() {

            pipelineStateDesc = MTLRenderPipelineDescriptor()
            let vertexFunction = defaultLibrary.makeFunction( name: "m4mQuadVertexShader" )
            pipelineStateDesc.vertexFunction = vertexFunction
            pipelineStateDesc.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
            
            pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
            pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
            pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
            pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                        
            func createNewPipelineState(_ fragmentFunction: MTLFunction?) -> MTLRenderPipelineState?
            {
                if let function = fragmentFunction {
                    pipelineStateDesc.fragmentFunction = function
                    do {
                        let renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDesc)
                        return renderPipelineState
                    } catch {
                        print( "createNewPipelineState failed" )
                        return nil
                    }
                }
                return nil
            }
            
            var function = defaultLibrary.makeFunction( name: "m4mDiscDrawable" )
            discState = createNewPipelineState(function)
            function = defaultLibrary.makeFunction( name: "m4mBoxDrawable" )
            boxState = createNewPipelineState(function)
        }
    }
    
    @discardableResult func encodeStart(_ clearColor: float4 = float4(0.125, 0.129, 0.137, 1)) -> MTLRenderCommandEncoder?
    {
        viewportSize = vector_uint2( UInt32(metalView.bounds.width), UInt32(metalView.bounds.height) )
        viewSize = float2(Float(metalView.bounds.width), Float(metalView.bounds.height))

        commandBuffer = commandQueue.makeCommandBuffer()!
                
        if let renderPassDescriptor = metalView.currentRenderPassDescriptor {
            
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor( red: Double(clearColor.x), green: Double(clearColor.y), blue: Double(clearColor.z), alpha: Double(clearColor.w))
        
            renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor )
            return renderEncoder
        }
        
        return nil
    }
    
    func encodeRun( _ renderEncoder: MTLRenderCommandEncoder, pipelineState: MTLRenderPipelineState? )
    {
        renderEncoder.setRenderPipelineState( pipelineState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    func encodeEnd()
    {
        renderEncoder?.endEncoding()
        
        guard let drawable = metalView.currentDrawable else {
            return
        }
        
        if let commandBuffer = commandBuffer {
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    /// Draws a disk
    func drawDisk(position: float2, radius: Float, borderSize: Float = 0, onion: Float = 0, rotation: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0))
    {
        var data = DiscUniform()
        data.borderSize = borderSize
        data.radius = radius
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.onion = onion
        data.rotation = rotation.degreesToRadians
        data.hasTexture = 0

        let rect = MMRect(position.x - data.borderSize / 2, position.y - data.borderSize / 2, data.radius * 2 + data.borderSize * 2, data.radius * 2 + data.borderSize * 2)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<DiscUniform>.stride, index: 0)
        renderEncoder.setRenderPipelineState(discState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws a box
    func drawBox(position: float2, size: float2, rounding: Float = 0, borderSize: Float = 0, onion: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0), texture: MTLTexture? = nil)
    {
        var data = BoxUniform()
        data.borderSize = borderSize
        data.size = size
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.onion = onion
        //data.rotation = rotation.degreesToRadians
        data.hasTexture = texture != nil ? 1 : 0
        data.round = rounding

        let rect = MMRect(position.x - data.borderSize / 2, position.y - data.borderSize / 2, size.x + data.borderSize * 2, size.y + data.borderSize * 2, scale: 1)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<BoxUniform>.stride, index: 0)
        if let texture = texture {
            renderEncoder.setFragmentTexture(texture, index: 1)
        }
        renderEncoder.setRenderPipelineState(boxState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Creates vertex data for the given rectangle
    func createVertexData(_ rect: MMRect) -> [Float]
    {
        let left: Float  = -viewSize.x / 2.0 + rect.x
        let right: Float = left + rect.width
        
        let top: Float = viewSize.y / 2.0 - rect.y
        let bottom: Float = top - rect.height

        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
        ]
        
        return quadVertices
    }
    
    /// Updates the view
    func update() {
        metalView.enableSetNeedsDisplay = true
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: metalView.frame.width, height: metalView.frame.height)
        metalView.setNeedsDisplay(nsrect)
        #else
        metalView.setNeedsDisplay()
        #endif
    }
}
