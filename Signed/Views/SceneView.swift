//
//  MainView.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct SceneView: View {
    
    @Environment(\.managedObjectContext) private var viewContext

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme
    
    let model                                           : Model

    @ObservedObject var project                         : Project
    
    @State var selectedPoint                            : Point? = nil
    @State var selectedLine                             : Line? = nil
    @State var selectedShape                            : Shape? = nil
    
    @State var xOffsetPopup                             : Float = 0
    @State var yOffsetPopup                             : Float = 0

    @State private var renamePointPopover               : Bool = false
    @State private var pointName                        : String = ""

    @State private var renameLinePopover                : Bool = false
    @State private var lineName                         : String = ""
    
    @State private var editPointPopover                 : Bool = false
    @State private var editContextPopover               : Bool = false
    @State private var editSettingsPopover              : Bool = false

    @State private var editPointsPopover                : Bool = false
    @State private var editLinesPopover                 : Bool = false
    @State private var editShapesPopover                : Bool = false
    
    @State private var renderIsMain                     : Bool = true
    @State private var showSideKick                     : Bool = true

    @State private var pathTraceIsOn                    : Bool = false
    @State private var bboxIsOn                         : Bool = true

    @State private var pointXValue                      = ""
    @State private var pointYValue                      = ""
    @State private var pointZValue                      = ""

    @State var modelIconColor                           : Color = .accentColor
    @State var renderIconColor                          : Color = .secondary
    
    @State var pointIconColor                           : Color = .accentColor
    @State var lineIconColor                            : Color = .secondary

    @State var showText                                 : String = "Points & Shapes"
    
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
        
        self._pathTraceIsOn = State(initialValue: project.trace)
        self._bboxIsOn = State(initialValue: project.bbox)
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            
            ZStack(alignment: .bottomLeading) {
                // Show tools
                                    
                if renderIsMain {
                    RenderView(model: model, mode: .Render3D)
                        .allowsHitTesting(true)
                    
                    /*
                    if editContextPopover {
                        VStack {
                            HStack {
                                Spacer()
                                Text("CLOSE")
                                    .onTapGesture {
                                        editContextPopover = false
                                    }
                                
                                //ShapeView(model: model, project: project, point: selectedPoint!, shape: selectedShape!)
                            }
                        }
                        .frame(width: 100)
                        .padding(.leading, CGFloat(xOffsetPopup) + 50)
                        .padding(.bottom, geometry.size.height - CGFloat(yOffsetPopup) - 50)
                    }*/
                    
                    if showSideKick {
                        PointCloud(model: model, project: project)
                            .frame(width: geometry.size.width / 4, height: geometry.size.height / 4)
                            .padding(.leading, geometry.size.width - geometry.size.width / 4)
                            .padding(.bottom, 0)
                    }
                } else {
                    PointCloud(model: model, project: project)
                        .allowsHitTesting(true)
                                 
                    if showSideKick {
                        RenderView(model: model, mode: .Render3D)
                            .frame(width: geometry.size.width / 4, height: geometry.size.height / 4)
                            .padding(.leading, geometry.size.width - geometry.size.width / 4)
                            .padding(.bottom, 0)
                    }
                }
                    
                
                if selectedPoint == nil && selectedLine == nil {
                    /*
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
                    }*/
                } else
                if let point = selectedPoint {
                    Menu {
                        Button("Rename", action: {
                            renamePointPopover = true
                            pointName = point.name!
                        })
                        
                        Button("Edit", action: {
                            editPointPopover = true
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
                        Text("Point: " + point.name!)
                    }
                    .padding(.trailing, 6)
                    .padding(.leading, 10)
                    .padding(.bottom, geometry.size.height - 25)
                    .frame(width: 150)
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    // Rename point
                    .popover(isPresented: self.$renamePointPopover,
                             arrowEdge: .bottom
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
                        }
                        .padding()
                    }
                    
                    /*
                    // Edit Shapes
                    .popover(isPresented: $editContextPopover,
                             attachmentAnchor: .rect(.rect(CGRectMake(geometry.size.width / 2, geometry.size.height, 200, 300))),//.point(UnitPoint(x:) 0.1, y: 0.5)),
                             arrowEdge: .bottom
                    ) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Test")
                            }
                        }
                        .padding()
                        .frame(width: 250)
                    }*/
                    
                    // Edit point
                    .popover(isPresented: self.$editPointPopover,
                             arrowEdge: .top
                    ) {
                        VStack(alignment: .leading) {
                            HStack {
                                
                                TextField("X Value", text: $pointXValue)
                                    .border(Color.red)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointXValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointXValue = filtered
                                        }
                                    }
                                
                                TextField("Y Value", text: $pointYValue)
                                    .border(Color.green)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointYValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointYValue = filtered
                                        }
                                    }
                                
                                TextField("Z Value", text: $pointZValue)
                                    .border(Color.blue)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointZValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointZValue = filtered
                                        }
                                    }
                            }
                        }
                        .padding()
                        .frame(width: 250)
                    }
                } else
                if let line = selectedLine {
                    Menu {
                        Button("Rename", action: {
                            renameLinePopover = true
                            lineName = line.name!
                        })
                        
                        Button("Delete", action: {
                            viewContext.delete(line)
                            model.lineChanged.send(nil)
                            save("Cannot delete line")
                            model.build()
                        })
                    }
                    label: {
                        Text("Line: " + line.name!)
                    }
                    .padding(.trailing, 6)
                    .padding(.leading, 10)
                    .padding(.bottom, geometry.size.height - 25)
                    .frame(width: 150)
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    // Rename line
                    .popover(isPresented: self.$renameLinePopover,
                             arrowEdge: .top
                    ) {
                        VStack(alignment: .leading) {
                            if let line = selectedLine {
                                Text("Name:")
                                TextField("Name", text: $lineName, onEditingChanged: { (changed) in
                                    line.name = lineName
                                    model.lineChanged.send(nil)
                                    model.lineChanged.send(line)
                                    save("Cannot rename line")
                                })
                                .frame(minWidth: 200)
                            }
                        }
                        .padding()
                    }
                    
                    /*
                    // Edit Shapes
                    .popover(isPresented: $editContextPopover,
                             attachmentAnchor: .rect(.rect(CGRectMake(geometry.size.width / 2, geometry.size.height, 200, 300))),//.point(UnitPoint(x:) 0.1, y: 0.5)),
                             arrowEdge: .bottom
                    ) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Test")
                            }
                        }
                        .padding()
                        .frame(width: 250)
                    }*/
                    
                    // Edit point
                    .popover(isPresented: self.$editPointPopover,
                             arrowEdge: .top
                    ) {
                        VStack(alignment: .leading) {
                            HStack {
                                
                                TextField("X Value", text: $pointXValue)
                                    .border(Color.red)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointXValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointXValue = filtered
                                        }
                                    }
                                
                                TextField("Y Value", text: $pointYValue)
                                    .border(Color.green)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointYValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointYValue = filtered
                                        }
                                    }
                                
                                TextField("Z Value", text: $pointZValue)
                                    .border(Color.blue)
                                    .disabled(selectedPoint == nil)
        #if os(iOS)
                                    .keyboardType(.numberPad)
        #endif
                                    .onReceive(Just(pointZValue)) { newValue in
                                        let filtered = newValue.filter { "0123456789.-+".contains($0) }
                                        if filtered != newValue {
                                            self.pointZValue = filtered
                                        }
                                    }
                            }
                        }
                        .padding()
                        .frame(width: 250)
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
        
        .toolbar {
            
            ToolbarItemGroup(placement: .automatic) {
                
                Button(action: {
                    renderIsMain.toggle()
                    model.renderIsMain = renderIsMain
                }) {
                    Label("Cycle", systemImage: "arrow.2.squarepath")
                        .imageScale(.large)
                }
                
                Button(action: {
                    withAnimation {
                        showSideKick.toggle()
                    }
                }) {
                    Label("SideKick", systemImage: showSideKick ? "cube.transparent.fill" : "cube.transparent")
                        .imageScale(.large)
                }
            
                Spacer()
                
                Button(action: {
                    editSettingsPopover = true
                }) {
                    Label("SETTINGS", systemImage: editSettingsPopover ? "gearshape.fill" : "gearshape")
                        .imageScale(.large)
                }
                .popover(isPresented: $editSettingsPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        //Section(header: Text("Render")) {
                            
                            Toggle("BSDF Pathtrace", isOn: $pathTraceIsOn)
                                .toggleStyle(.switch)
                        
                            Toggle("Show Bounding Box", isOn: $bboxIsOn)
                                .toggleStyle(.switch)
                        //}

                        Spacer()
                    }
                    .padding()
                    .frame(width: 250, height: 400)
                }
            
                Spacer()

            
                /*
                ToolbarItemGroup(placement: .automatic) {
                    
                    Menu(content: {
                        Section(header: Text("Show")) {
                            Button("Points & Shapes", action: {
                                project.showPoints = true
                                project.showShapes = true
                                model.rebuild.send()
                                showText = "Points & Shapes"
                                save("")
                            })
                            .keyboardShortcut("1")
                            Button("Points Only", action: {
                                project.showPoints = true
                                project.showShapes = false
                                model.rebuild.send()
                                showText = "Points Only"
                                save("")
                            })
                            .keyboardShortcut("2")
                            Button("Shapes Only", action: {
                                project.showPoints = false
                                project.showShapes = true
                                model.rebuild.send()
                                showText = "Shapes Only"
                                save("")
                            })
                            .keyboardShortcut("3")
                        }
                    }, label: {
                        Text(showText)
                    })
                }*/
                            
                Button(action: {
                    editPointsPopover = true
                }) {
                    Label("POINTS", systemImage: editPointsPopover ? "circle.fill" : "circle")
                }
                .popover(isPresented: $editPointsPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        
                        HStack(alignment: .center) {
                            Text("POINTS")
                                .font(.system(size: 20))
                                .padding(.top, 10)
                                .padding(.leading, 10)

                            Spacer()
                            
                            Button(action: {
                                
                                let point = Point(context: viewContext)
                                
                                point.name = "Unnamed"
                                point.id = UUID()
                                
                                point.x = 0.0
                                point.y = 0.0
                                point.z = 0.0
                                
                                point.red = Float.random(in: 0...1)
                                point.green = Float.random(in: 0...1)
                                point.blue = Float.random(in: 0...1)
                                
                                point.shapes = []
                                
                                project.addToPoints(point)

                                save("Cannot add point")
                            }) {
                                Label("", systemImage: "plus")
                            }
                            .padding(.top, 10)
                            .padding(.trailing, 5)
                            .imageScale(.large)
                            .buttonStyle(.borderless)
                        }
                        
                        List {
                            ForEach((project.points!.allObjects as! [Point]).sorted { $0.index < $1.index } ) { point in
                                Text(point.name!)
                                    .font(.system(size: 18))
                                    .onTapGesture {
                                        model.pointChanged.send(point)
                                    }
                                    .foregroundColor(point.id == selectedPoint?.id ? .accentColor : .secondary)
                            }
                             .onDelete(perform: { offsets in
                                 offsets.map { project.points?.allObjects[$0] as! NSManagedObject }.forEach(viewContext.delete)
                                 
                                 self.selectedPoint = nil
                                 do {
                                     try viewContext.save()
                                 } catch {
                                     let nsError = error as NSError
                                     print("Cannot delete point", nsError)
                                 }
                             })
                        }
                        .listStyle(PlainListStyle())
                        .cornerRadius(10.0)
                    }
                    .frame(width: 300, height: 600)
                }
                
                Button(action: {
                    editLinesPopover = true
                }) {
                    Label("LINES", systemImage: editLinesPopover ? "line.diagonal" : "line.diagonal")
                        .imageScale(.large)
                }
                .popover(isPresented: $editLinesPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        
                        HStack(alignment: .center) {
                            Text("LINES")
                                .font(.system(size: 20))
                                .padding(.top, 10)
                                .padding(.leading, 10)

                            Spacer()
                            
                            Button(action: {
                                
                                let line = Line(context: viewContext)
                                
                                line.name = "Unnamed"
                                line.id = UUID()
                                
                                line.startPoint = nil
                                line.endPoint = nil
                                
                                line.shapes = []
                                
                                project.addToLines(line)

                                save("Cannot add line")
                            }) {
                                Label("", systemImage: "plus")
                            }
                            .padding(.top, 10)
                            .padding(.trailing, 5)
                            .imageScale(.large)
                            .buttonStyle(.borderless)
                        }
                        
                        List {
                            ForEach((project.lines!.allObjects as! [Line]).sorted { $0.index < $1.index } ) { line in
                                LineView(model: model, project: project, line: line)
                            }
                             .onDelete(perform: { offsets in
                                 offsets.map { project.lines?.allObjects[$0] as! NSManagedObject }.forEach(viewContext.delete)
                                 
                                 self.selectedLine = nil
                                 do {
                                     try viewContext.save()
                                 } catch {
                                     let nsError = error as NSError
                                     print("Cannot delete line", nsError)
                                 }
                             })
                        }
                        .listStyle(PlainListStyle())
                        .cornerRadius(10.0)
                    }
                    .frame(width: 300, height: 600)
                }

                Button(action: {
                    editShapesPopover = true
                }) {
                    Label("SHAPES", systemImage: editShapesPopover ? "cube.fill" : "cube")
                        .imageScale(.large)
                }
                .disabled(selectedPoint == nil && selectedLine == nil)
                .popover(isPresented: $editShapesPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        
                        HStack(alignment: .center) {
                            Text("Shapes")
                                .font(.system(size: 20))
                                .padding(.top, 10)
                                .padding(.leading, 10)

                            Spacer()
                            
                            Button(action: {
                                
                                let shape = Shape(context: viewContext)
                                
                                shape.name = "Unnamed"
                                shape.id = UUID()
                                shape.blendModeName = "Add"
                                
                                shape.x = 0.0
                                shape.y = 0.0
                                shape.z = 0.0
                                
                                shape.radius = 0.2
                                shape.sizeX = 0.2
                                shape.sizeY = 0.2
                                shape.sizeZ = 0.2
                                                                
                                if let selectedPoint = selectedPoint {
                                    
                                    shape.index = Int16(selectedPoint.shapes!.count)
                                    
                                    selectedPoint.addToShapes(shape)
                                    self.selectedPoint = nil
                                    self.selectedPoint = selectedPoint
                                } else
                                if let selectedLine = selectedLine {
                                    shape.index = Int16(selectedLine.shapes!.count)
                                    
                                    selectedLine.addToShapes(shape)
                                    self.selectedLine = nil
                                    self.selectedLine = selectedLine
                                }
                                selectedShape = shape

                                save("Cannot add shape")
                            }) {
                                Label("", systemImage: "plus")
                            }
                            .padding(.top, 10)
                            .padding(.trailing, 5)
                            .imageScale(.large)
                            .buttonStyle(.borderless)
                        }
                        
                        if let selectedPoint = selectedPoint {
                            
                            List {
                                ForEach((selectedPoint.shapes!.allObjects as! [Shape]).sorted { $0.index < $1.index } ) { shape in
                                    ShapeView(model: model, project: project, shape: shape)
                                }
                                 .onDelete(perform: { offsets in
                                     offsets.map { selectedPoint.shapes?.allObjects[$0] as! NSManagedObject }.forEach(viewContext.delete)
                                     
                                     self.selectedPoint = nil
                                     self.selectedPoint = selectedPoint
                                     selectedShape = nil
                                     do {
                                         try viewContext.save()
                                     } catch {
                                         let nsError = error as NSError
                                         print("Cannot delete shapes", nsError)
                                     }
                                 })
                            }
                            .listStyle(PlainListStyle())
                            .cornerRadius(10.0)
                        } else
                        if let selectedLine = selectedLine {
                            
                            List {
                                ForEach((selectedLine.shapes!.allObjects as! [Shape]).sorted { $0.index < $1.index } ) { shape in
                                    ShapeView(model: model, project: project, shape: shape)
                                }
                                 .onDelete(perform: { offsets in
                                     offsets.map { selectedLine.shapes?.allObjects[$0] as! NSManagedObject }.forEach(viewContext.delete)
                                     
                                     self.selectedLine = nil
                                     self.selectedLine = selectedLine
                                     selectedShape = nil
                                     do {
                                         try viewContext.save()
                                     } catch {
                                         let nsError = error as NSError
                                         print("Cannot delete shapes", nsError)
                                     }
                                 })
                            }
                            .listStyle(PlainListStyle())
                            .cornerRadius(10.0)
                        }
                        
                    }
                    #if os(iOS)
                    .frame(width: 300, height: 600)
                    #else
                    .frame(width: 300, height: 600)
                    #endif
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        
        .onReceive(model.projectChanged) { project in
            if project?.trace == true {
                modelIconColor = .secondary
                renderIconColor = .accentColor
            } else {
                modelIconColor = .accentColor
                renderIconColor = .secondary
            }
            if project?.showPoints == true && project?.showShapes == true {
                showText = "Points & Shapes"
            } else
            if project?.showPoints == true {
                showText = "Points Only"
            } else {
                showText = "Shapes Only"
            }
        }
            
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
            self.selectedLine = nil
//            if let point = point {
//                pointXValue = String(point.x)
//                pointYValue = String(point.y)
//                pointZValue = String(point.z)
//            }
        }
        
        .onReceive(self.model.lineChanged) { line in
            self.selectedPoint = nil
            self.selectedLine = line
        }
        
        .onReceive(self.model.showContext) { ctx in
            self.editContextPopover = true
            self.xOffsetPopup = ctx.2
            self.yOffsetPopup = ctx.3
        }
        
        .onChange(of: pathTraceIsOn) { newValue in
            project.trace = newValue
            model.renderer?.restart()
            save("pathtrace")
        }
        
        .onChange(of: bboxIsOn) { newValue in
            project.bbox = newValue
            model.renderer?.restart()
            save("bbox")
        }
        
        .onChange(of: pointXValue) { newValue in
            if let point = selectedPoint {
                if let v = Float(newValue) {
                    point.x = v
                    save("Cannot edit point")
                    model.rebuild.send()
                }
            }
        }
        
        .onChange(of: pointYValue) { newValue in
            if let point = selectedPoint {
                if let v = Float(newValue) {
                    point.y = v
                    save("Cannot edit point")
                    model.rebuild.send()
                }
            }
        }
        
        .onChange(of: pointZValue) { newValue in
            if let point = selectedPoint {
                if let v = Float(newValue) {
                    point.z = v
                    save("Cannot edit point")
                    model.rebuild.send()
                }
            }
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
