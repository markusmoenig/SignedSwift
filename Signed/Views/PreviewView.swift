//
//  PreviewView.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import SwiftUI

#if os(iOS)
import MobileCoreServices
#endif

struct PreviewView: View {
    
    @Environment(\.managedObjectContext) private var viewContext

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme
    
    let model                                           : Model

    @ObservedObject var project                         : Project
    
    @State var selectedPoint                            : Point? = nil
    @State var selectedShape                            : Shape? = nil
    
    @State private var renamePointPopover               : Bool = false
    @State private var pointName                        : String = ""

    @State var cameraMode                               : ModelerKit.Content = .project
    @State var selection                                : SignedObject? = nil
    
    @State var updateView                               : Bool = false

    @State private var showCustomResPopover             : Bool = false
    @State private var customResWidth                   : String = ""
    @State private var customResHeight                  : String = ""

    @State private var resolutionText                   : String = ""

    @State private var exportingImage                   : Bool = false
        
    @State private var isOrbiting                       : Bool = false
    @State private var isMoving                         : Bool = false
    @State private var isZooming                        : Bool = false
        
    init(model: Model, project: Project) {
        self.model = model
        self.project = project
        
        model.projectChanged.send(project)
    }
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 4) {

            GeometryReader { geometry in
                
                ZStack(alignment: .bottomLeading) {
                    // Show tools
                    
                    RenderView(model: model, mode: .Render3D)
                    //.animation(.default)
                        .allowsHitTesting(true)
                    
                    if project.render == true {
                        Menu {
                            Button("Set Custom", action: {
                                                                
                                if let mainRenderKit = model.renderer?.mainRenderKit {
                                    let width = mainRenderKit.sampleTexture!.width
                                    let height = mainRenderKit.sampleTexture!.height
                                    
                                    model.renderSize = SIMD2<Int>(width, height)
                                    customResWidth = String(width)
                                    customResHeight = String(height)
                                }
                                
                                showCustomResPopover = true
                            })
                            
                            Button("Clear Custom", action: {
                                model.renderSize = nil
                                model.renderer?.restart()
                            })
                            
                            Divider()
                            
                            Button("Export Image...", action: {
                                exportingImage = true
                            })
                        }
                        label: {
                            Text(resolutionText)
                        }
                        .padding(.trailing, 6)
                        .padding(.leading, 10)
                        .padding(.bottom, geometry.size.height - 25)
                        .frame(width: 100)
                        .menuStyle(BorderlessButtonMenuStyle())
                            
                            // Custom Resolution Popover
                        .popover(isPresented: self.$showCustomResPopover,
                                 arrowEdge: .top
                        ) {
                            VStack(alignment: .leading) {
                                Text("Resolution:")
                                TextField("Width", text: $customResWidth, onEditingChanged: { (changed) in
                                })
                                TextField("Height", text: $customResHeight, onEditingChanged: { (changed) in
                                })
                                
                                Button(action: {
                                    if let width = Int(customResWidth), width > 0 {
                                        if let height = Int(customResHeight), height > 0 {
                                            model.renderSize = SIMD2<Int>(width, height)
                                            model.renderer?.restart()
                                        }
                                    }
                                })
                                {
                                    Text("Apply")
                                }
                                .foregroundColor(Color.accentColor)
                                .padding(4)
                                .padding(.leading, 10)
                                .frame(minWidth: 200)
                            }.padding()
                        }
                    } else 
                    if let point = selectedPoint {
                        Menu {
                            Button("Rename", action: {
                                renamePointPopover = true
                                pointName = point.name!
                            })
                            
                            Button("Delete", action: {
                                viewContext.delete(point)
                                model.pointChanged.send(nil)
                                save("Cannot delete point")
                                model.build()
                            })
                            
//                            Divider()
//                            
//                            Button("Export Image...", action: {
//                                exportingImage = true
//                            })
                        }
                        label: {
                            Text(point.name!)
                        }
                        .padding(.trailing, 6)
                        .padding(.leading, 10)
                        .padding(.bottom, geometry.size.height - 25)
                        .frame(width: 100)
                        .menuStyle(BorderlessButtonMenuStyle())
                        
                        // Edit Node name
                        .popover(isPresented: self.$renamePointPopover,
                                 arrowEdge: .top
                        ) {
                            VStack(alignment: .leading) {
                                if let point = selectedPoint {
                                    Text("Name:")
                                    TextField("Name", text: $pointName, onEditingChanged: { (changed) in
                                        point.name = pointName
                                        model.pointChanged.send(nil)
                                        model.pointChanged.send(point)
                                        save("Cannot rename Point")
                                    })
                                    .frame(minWidth: 200)
                                }
                            }.padding()
                        }
                    }
                    
                    // Camera Controls
                    
                    if cameraMode != .material {
                        Button(action: {
                            
                        })
                        {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 0)
                                Text("Orbit")
                            }
                        }
                        .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                        .font(.system(size: 16))
                        .background(isOrbiting ? Color.accentColor : Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 70)
                        .buttonStyle(.plain)
                        
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                            
                                .onChanged({ info in
                                    
                                    isOrbiting = true
                                    let camera = getCamera()
                                    let delta = float2(Float(info.location.x - info.startLocation.x), 0)//Float(info.location.y - info.startLocation.y))
                                    
                                    camera.rotateDelta(delta * 0.01)
                                    model.renderer?.restart()
                                })
                                .onEnded({ info in
                                    isOrbiting = false
                                    let camera = getCamera()
                                    camera.lastDelta = float2(0,0)
                                })
                        )
                        
                        Button(action: {
                            
                        })
                        {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 0)
                                Text("Move")
                            }
                        }
                        .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                        .font(.system(size: 16))
                        .background(isMoving ? Color.accentColor : Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 40)
                        .buttonStyle(.plain)
                        
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                            
                                .onChanged({ info in
                                    
                                    isMoving = true
                                    let camera = getCamera()
                                    let delta = float2(/*Float(info.location.x - info.startLocation.x)*/0, Float(info.location.y - info.startLocation.y))
                                    
                                    camera.moveDelta(delta * 0.003, aspect: getAspectRatio())
                                    model.renderer?.restart()
                                })
                                .onEnded({ info in
                                    isMoving = false
                                    let camera = getCamera()
                                    camera.lastDelta = float2(0,0)
                                })
                        )
                    }
                    
                    Button(action: {
                        
                    })
                    {
                        ZStack(alignment: .center) {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 0)
                            Text("Zoom")
                        }
                    }
                    .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                    .font(.system(size: 16))
                    .background(isZooming ? Color.accentColor : Color.clear)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                    .buttonStyle(.plain)
                    
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4)
                        
                            .onChanged({ info in
                                
                                isZooming = true
                                let camera = getCamera()
                                let delta = float2(Float(info.location.x - info.startLocation.x), Float(info.location.y - info.startLocation.y))
                                
                                camera.zoomDelta(delta.x * 0.04)
                                model.renderer?.restart()
                            })
                            .onEnded({ info in
                                isZooming = false
                                let camera = getCamera()
                                camera.lastZoomDelta = 0
                            })
                    )
                }
            }
            
            /*
             // Export Image
             .fileExporter(
             isPresented: $exportingImage,
             document: document,
             contentType: .png,
             defaultFilename: "Image"
             ) { result in
             do {
             let url = try result.get()
             
             if let image = document.model.modeler?.kitToImage(renderKit: document.model.renderer!.mainRenderKit) {
             if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
             CGImageDestinationAddImage(imageDestination, image, nil)
             CGImageDestinationFinalize(imageDestination)
             }
             }
             } catch {
             // Handle failure.
             }
             }*/
            
            
            .onReceive(self.model.updateUI) { _ in
                resolutionText = computeResolutionText()
                updateView.toggle()
            }
            
            .onReceive(model.cameraModeChanged) { mode in
                cameraMode = mode
            }
            
            .onAppear() {
                model.projectChanged.send(project)
            }
            
            .onReceive(self.model.pointChanged) { point in
                self.selectedPoint = point
            }

            Sidebar(model: model, project: project)
                .frame(width: 300)
        }
    }
    
    /// Returns the resolution of the current preview
    func computeResolutionText() -> String {
        let string = ""
        if let mainRenderKit = model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return "\(width) x \(height)"
        }
        return string
    }
    
    /// Returns the resolution of the current preview
    func getAspectRatio() -> Float {
        if let mainRenderKit = model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return Float(width) / Float(height)
        }
        return 1
    }
    
    /// Returns the right camera for the current mode
    func getCamera() -> SignedPinholeCamera {
        if cameraMode == .object {
            return model.project.objectCamera
        } else
        if cameraMode == .material {
            return model.project.materialCamera
        } else {
            return model.project.camera
        }
    }
    
    /// Save the context
    func save(_ text: String) {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print(text, nsError)
        }
    }
}
