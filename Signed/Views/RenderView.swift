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
    
    enum Axis {
        case XY
    }
    
    enum Mode {
        case Points3D
        case Render3D
    }
    
    var mode                : Mode = .Render3D
    var axis                : Axis = .XY
    
    var pointRadius         : Float = 10.0
    
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

    var currentPoint        : Point? = nil
    
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
        if mode == .Render3D {
            renderer?.renderSample()
            if drawables?.encodeStart(float4(0,0,0,0)) != nil {
                
                if let texture = model.renderer?.mainRenderKit.outputTexture {
                    drawables?.drawBox(position: float2(0,0), size: float2(Float(texture.width), Float(texture.height)), rounding: 0, borderSize: 0, onion: 0, fillColor: float4(0,0,0,1), borderColor: float4(0,0,0,0), texture: texture)
                }
                
                drawables?.encodeEnd()
            }
        } else
        if mode == .Points3D {
            if drawables?.encodeStart(float4(0.0,0.0,0.0,0.0)) != nil {
                
                model.renderer?.renderPointCloud(width: Int(drawables!.metalView.frame.width), height: Int(drawables!.metalView.frame.height))
                if let texture = model.renderer?.pointCloudTexture {
                    
                    drawables?.drawBox(position: float2(0,0), size: float2(Float(texture.width), Float(texture.height)), rounding: 0, borderSize: 0, onion: 0, fillColor: float4(0,0,0,1), borderColor: float4(0,0,0,0), texture: texture)
                }
                
                /*
                if let points = model.currProject?.points {
                    
                    for p in points.allObjects as! [Point] {
                        
                        let x = (p.x + 0.5) * Float(self.drawables!.metalView.bounds.width) - self.pointRadius
                        let y = (1.0 - (p.y + 0.5)) * Float(self.drawables!.metalView.bounds.height) - self.pointRadius

                        var borderSize : Float = 0.0
                        
                        if let currentPoint = currentPoint {
                            if currentPoint.id == p.id {
                                borderSize = 2.0
                            }
                        }
                        
                        drawables?.drawDisk(position: float2(x, y), radius: pointRadius, borderSize: borderSize, fillColor: float4(p.red, p.green, p.blue, 1.0), borderColor: float4(1, 1, 1, 1))
                    }
                }*/
                
                drawables?.encodeEnd()
            }
        }
    }
    
    #if os(OSX)

    /// Setup the view
    func platformInit(_ model: Model)
    {
        drawables = MetalDrawables(self)
        
        if mode == .Render3D {
            model.setRenderView(self)
        } else
        if mode == .Points3D {
            model.setPointsView(self)
        }

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
        
        if mode == .Render3D {
            let size = float2(Float(frame.width), Float(frame.height))
            if let rc = model.modeler?.getSceneHit(mousePos / size, size) {
                let id = rc.2
                                
                for (i, uuid) in model.pointMap {
                    if id > i - 0.005 && id < i + 0.005 {
                        if let project = model.currProject {
                            for p in project.points?.allObjects as! [Point] {
                                if p.id == uuid {
                                    model.pointChanged.send(p)
                                    //model.showContext.send((nil, nil, mousePos.x, mousePos.y))
                                    break
                                }
                            }
                            for l in project.lines?.allObjects as! [Line] {
                                if l.id == uuid {
                                    model.lineChanged.send(l)
                                    //model.showContext.send((nil, nil, mousePos.x, mousePos.y))
                                    break
                                }
                            }
                        }
                    }
                }
            }
        } else
        if mode == .Points3D {
            let size = float2(Float(frame.width), Float(frame.height))
            if let rc = model.modeler?.getPointCloudHit(mousePos / size, size) {
                let id = rc.w
                
                for (i, uuid) in model.pointMap {
                    if id > i - 0.005 && id < i + 0.005 {
                        if let project = model.currProject {
                            for p in project.points?.allObjects as! [Point] {
                                if p.id == uuid {
                                    model.pointChanged.send(p)
                                    //model.showContext.send((nil, nil, mousePos.x, mousePos.y))
                                    break
                                }
                            }
                            for l in project.lines?.allObjects as! [Line] {
                                if l.id == uuid {
                                    model.lineChanged.send(l)
                                    //model.showContext.send((nil, nil, mousePos.x, mousePos.y))
                                    break
                                }
                            }
                        }
                    }
                }
                
                let p = float3(rc.x, rc.y, rc.z)
                if p.x >= -0.5 && p.x <= 0.5 && p.y >= -0.5 && p.y <= 0.5 && p.z >= -0.5 && p.z <= 0.5 {
                    
                }
            }
        }
    }
    
    override public func mouseDragged(with event: NSEvent) {
        setMousePos(event)
        
        if mode == .Points3D && model.pointEditAxisMode != POINT_AXIS_NONE {
            if let point = model.currPoint {
                let size = float2(Float(frame.width), Float(frame.height))
                if let rc = model.modeler?.getPointCloudHit(mousePos / size, size) {
                    var p = float3(rc.x, rc.y, rc.z)
                    
                    p.x = p.x.clamped(to: -0.5 ... 0.5)
                    p.y = p.y.clamped(to: -0.5 ... 0.5)
                    p.z = p.z.clamped(to: -0.5 ... 0.5)

                    if model.pointEditAxisMode == POINT_AXIS_XZ {
                        point.x = p.x
                        point.z = p.z
                    } else
                    if model.pointEditAxisMode == POINT_AXIS_XY {
                        point.x = p.x
                        point.y = p.y
                    } else
                    if model.pointEditAxisMode == POINT_AXIS_YZ {
                        point.y = p.y
                        point.z = p.z
                    }
                    model.pointChanged.send(point)
                    model.build()
                }
            }
        }
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
        
        if mode == .Render3D {
            model.setRenderView(self)
        } else
        if mode == .Points3D {
            model.setPointsView(self)
        }

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
        
        let size = float2(Float(frame.width), Float(frame.height))
        if let rc = model.modeler?.getSceneHit(mousePos / size, size) {
            let id = rc.2
            
            for (i, uuid) in model.pointMap {
                if id > i - 0.005 && id < i + 0.005 {
                    if let project = model.currProject {
                        for p in project.points?.allObjects as! [Point] {
                            if p.id == uuid {
                                model.pointChanged.send(p)
                                break
                            }
                        }
                    }
                }
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
    var mode                : SMTKView.Mode
    
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
        
        stkView.mode = mode
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
    var mode                : SMTKView.Mode
    
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
        
        stkView.mode = mode
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
