//
//  RenderView.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import SwiftUI
import MetalKit

public class SMTKView       : MTKView
{
    
    var model               : Model!
    
    var keysDown            : [Float] = []
    
    var mouseIsDown         : Bool = false
    var mousePos            = float2(0, 0)
    
    var hasTap              : Bool = false
    var hasDoubleTap        : Bool = false
    
    var buttonDown          : String? = nil
    var swipeDirection      : String? = nil

    var commandIsDown       : Bool = false
    var shiftIsDown         : Bool = false
    
    var renderer            : RenderPipeline? = nil
    var drawables           : MetalDrawables? = nil
//
//    var currentEditingCmd   : SignedCommand? = nil
    
    func reset()
    {
        keysDown = []
        mouseIsDown = false
        hasTap  = false
        hasDoubleTap  = false
        buttonDown = nil
        swipeDirection = nil
    }
    
    func update()
    {
        renderer?.renderSample()
        if drawables?.encodeStart(float4(0,0,0,1)) != nil {
            
            if let texture = model.renderer?.mainRenderKit.outputTexture {
                drawables?.drawBox(position: float2(0,0), size: float2(Float(texture.width), Float(texture.height)), rounding: 0, borderSize: 0, onion: 0, fillColor: float4(0,0,0,1), borderColor: float4(0,0,0,0), texture: texture)
            }
            
            drawables?.encodeEnd()
        }
    }
    
    #if os(OSX)

    /// Setup the view
    func platformInit(_ model: Model)
    {
        drawables = MetalDrawables(self)
        model.setRenderView(self)
        self.model = model

        layer?.isOpaque = false
    }
    
    override public var acceptsFirstResponder: Bool { return true }

    /// To get continuous mouse events on macOS
    override public func updateTrackingAreas()
    {
        let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                      owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    func setMousePos(_ event: NSEvent)
    {
        var location = event.locationInWindow
        location.y = location.y - CGFloat(frame.height)
        location = convert(location, from: nil)
        
        mousePos.x = Float(location.x)
        mousePos.y = -Float(location.y)
    }
    
    override public func keyDown(with event: NSEvent)
    {
        keysDown.append(Float(event.keyCode))
    }
    
    override public func keyUp(with event: NSEvent)
    {
        keysDown.removeAll{$0 == Float(event.keyCode)}
    }
        
    override public func mouseDown(with event: NSEvent) {
        setMousePos(event)
        
        if event.clickCount > 1 {
            hasDoubleTap = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) {
                self.hasDoubleTap = false
            }
        }
    }
    
    override public func mouseDragged(with event: NSEvent) {
        setMousePos(event)
    }
    
    override public func mouseMoved(with event: NSEvent) {
        setMousePos(event)
                
        //let size = float2(Float(frame.width), Float(frame.height))
        //model.modeler?.getSceneHit(mousePos / size, size)
    }
    
    override public func mouseUp(with event: NSEvent) {
        
        mouseIsDown = false
        hasTap = false
        hasDoubleTap = false
        setMousePos(event)
    }
    
    #elseif os(iOS)

    /// Setup the view
    func platformInit(_ model: Model, command: SignedCommand? = nil)
    {
        drawables = MetalDrawables(self)
        model.setRenderView(self)
        self.model = model
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action:(#selector(self.handleTapGesture(_:))))
        tapRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapRecognizer)
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action:(#selector(self.handlePanGesture(_:))))
        panRecognizer.minimumNumberOfTouches = 2
        addGestureRecognizer(panRecognizer)
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:(#selector(self.handlePinchGesture(_:))))
        addGestureRecognizer(pinchRecognizer)
    }

    @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer)
    {
        if recognizer.numberOfTouches == 1 {
            hasTap = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) {
                self.hasTap = false
            }
        } else
        if recognizer.numberOfTouches >= 1 {
            hasDoubleTap = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) {
                self.hasDoubleTap = false
            }
        }
    }

    var lastX, lastY    : Float?
    @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer)
    {
        if recognizer.numberOfTouches > 1 {
            let translation = recognizer.translation(in: self)
            
            if ( recognizer.state == .began ) {
                lastX = 0
                lastY = 0
            }
            
            let delta = float3(Float(translation.x) - lastX!, Float(translation.y) - lastY!, Float(recognizer.numberOfTouches))
            
            lastX = Float(translation.x)
            lastY = Float(translation.y)
            
            //if let node = core.graphBuilder.currentNode {
            //    node.toolScrollWheel(delta, core.toolContext)
            //}
        }
    }

    var firstTouch      : Bool = false
    @objc func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer)
    {
        //if let cameraNode = getCameraNode() {
        //    cameraNode.toolPinchGesture(Float(recognizer.scale), firstTouch, core.toolContext)
        //}
        
        firstTouch = false
    }

    func setMousePos(_ x: Float, _ y: Float)
    {
        mousePos.x = x
        mousePos.y = y
        
        //mousePos.x /= Float(bounds.width) / core.texture!.width// / game.scaleFactor
        //mousePos.y /= Float(bounds.height) / core.texture!.height// / game.scaleFactor
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        mouseIsDown = true
        firstTouch = true
        if let touch = touches.first {
            let point = touch.location(in: self)
            setMousePos(Float(point.x), Float(point.y))
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            setMousePos(Float(point.x), Float(point.y))
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        mouseIsDown = false
        if let touch = touches.first {
            let point = touch.location(in: self)
            setMousePos(Float(point.x), Float(point.y))
        }
    }
    #endif
}

#if os(OSX)
struct RenderView: NSViewRepresentable {

    var model               : Model
    var trackingArea        : NSTrackingArea?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<RenderView>) -> MTKView {
        let stkView = SMTKView(frame: NSMakeRect(0, 0, 100, 100))
        
        stkView.delegate = context.coordinator
        stkView.preferredFramesPerSecond = 60
        stkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            stkView.device = metalDevice
        }
        stkView.framebufferOnly = false
        stkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        stkView.drawableSize = stkView.frame.size
        stkView.isPaused = false
        
        stkView.platformInit(model)

        return stkView
    }
    
    func updateNSView(_ view: MTKView, context: NSViewRepresentableContext<RenderView>) {
        if let stkView = view as? SMTKView {
            stkView.update()
        }
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: RenderView
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        init(_ parent: RenderView) {
            self.parent = parent
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let stkView = view as? SMTKView {
                stkView.update()
            }
        }
        
        func draw(in view: MTKView) {
            if let stkView = view as? SMTKView {
                stkView.update()
            }
        }
    }
}
#else
struct RenderView: UIViewRepresentable {
    typealias UIViewType = MTKView

    var model               : Model
    var command             : SignedCommand? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: UIViewRepresentableContext<RenderView>) -> MTKView {
        let stkView = SMTKView()
        
        stkView.delegate = context.coordinator
        stkView.preferredFramesPerSecond = 60
        stkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            stkView.device = metalDevice
        }
        stkView.framebufferOnly = false
        stkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        stkView.drawableSize = stkView.frame.size
        stkView.isPaused = false
        
        stkView.platformInit(model, command: command)

        return stkView
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<RenderView>) {
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: RenderView
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        
        init(_ parent: RenderView) {
            self.parent = parent
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        func draw(in view: MTKView) {
            if let stkView = view as? SMTKView {
                stkView.update()
            }
        }
    }
}
#endif
