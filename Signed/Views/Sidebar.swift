//
//  Sidebar.swift
//  Signed
//
//  Created by Markus Moenig on 20/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct Sidebar: View {
    
    @Environment(\.managedObjectContext) private var viewContext

    let model                               : Model

    @ObservedObject var project             : Project

    @State var selectedPoint                : Point? = nil
    @State var selectedShape                : Shape? = nil

    @State var modelIconColor               : Color = .accentColor
    @State var renderIconColor              : Color = .secondary
    
    @State var pointIconColor               : Color = .accentColor
    @State var lineIconColor                : Color = .secondary

    @State var showText                     : String = "Points & Shapes"

    var body: some View {
        
        // Shape List
        
        VStack(alignment: .leading) {
            
            if let selectedPoint = selectedPoint {
        
                HStack(alignment: .center) {
                    Text("Shapes")
                        .font(.system(size: 20))
                        .padding(.top, 5)
                        .padding(.leading, 10)

                    Spacer()
                    
                    Button(action: {
                        
                        let shape = Shape(context: viewContext)
                        
                        shape.name = "Unnamed"
                        shape.id = UUID()
                        
                        shape.x = 0.0
                        shape.y = 0.0
                        shape.z = 0.0
                        
                        let bsdf = BSDF(context: viewContext)
                        bsdf.red = 0.5
                        bsdf.green = 0.5
                        bsdf.blue = 0.5
                        bsdf.roughness = 0.5
                        bsdf.metallic = 0.0
                        
                        shape.material = bsdf
                        
                        selectedPoint.addToShapes(shape)
                        self.selectedPoint = nil
                        self.selectedPoint = selectedPoint
                        selectedShape = shape
                        
                        save("Cannot add shape")
                    }) {
                        Label("", systemImage: "plus")
                    }
                    .padding(.top, 5)
                    .padding(.trailing, 10)
                    .imageScale(.large)
                    .buttonStyle(.borderless)
                }
                
                List {
                    ForEach(selectedPoint.shapes?.allObjects as! [Shape]) { shape in
                        //Section(header: Text(shape.name!)) {
                        
                        ShapeView(model: model, project: project, point: selectedPoint, shape: shape)
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
            }
        }
        //.padding(10)

        
        /*
        TabView {

            VStack(alignment: .leading) {
                if pointIconColor == .accentColor {
                    
                    RenderView(model: model, mode: .Points2D)
                        .frame(width: 200, height: 200)
                    
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
                        
                        if project.points?.allObjects.count == 0 {
                            project.points = [point]
                        } else {
                            project.addToPoints(point)
                        }
                        
                        save("Cannot add point")
                    }) {
                        Text("Add Point")
                    }
                    
                    HStack {
                        
                        TextField("X Value", text: $pointXValue)
                            .border(Color.red)
                            .disabled(currentPoint == nil)
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
                            .disabled(currentPoint == nil)
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
                            .disabled(currentPoint == nil)
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
                } else
                if lineIconColor == .accentColor {
                    Text("Line")
                }
                
                Spacer()
            }
            .padding(10)
            .tabItem {
                Image(systemName: "circle.fill")
                Text("Point")
            }
        
            List {
                
                // Add Shape
                
                Button(action: {
                    
                    if let currentPoint = currentPoint {
                        let shape = Shape(context: viewContext)
                        
                        shape.name = "Unnamed"
                        shape.id = UUID()
                        
                        shape.x = 0.0
                        shape.y = 0.0
                        shape.z = 0.0
                        
                        currentPoint.addToShapes(shape)
                        self.currentPoint = nil
                        self.currentPoint = currentPoint
                        currentShape = shape
                    }

                    save("Cannot add shape")
                }) {
                    Text("Add Shape")
                }
                .disabled(currentPoint == nil)

                // Shape List
                
                if let currentPoint = currentPoint {
                    //List {
                        ForEach(currentPoint.shapes?.allObjects as! [Shape]) { shape in
                            //Section(header: Text(shape.name!)) {
                                
                                Text(shape.name!)
                                    .onTapGesture(perform: {
                                        currentShape = shape
                                    })
                            
                                Menu(content: {
                                    Button(action: {
                                    }) {
                                        Text("Sphere")
                                    }
                                }, label: {
                                    Text("Shape")
                                })

//                                Text(shape.name!)
//                                    .foregroundStyle(currentShape == shape ? .blue : .secondary)
//                                    .onTapGesture(perform: {
//                                        currentShape = shape
//                                    })

                            //}
                            
                            Divider()
                        }
                        .onDelete(perform: { offsets in
                            offsets.map { currentPoint.shapes?.allObjects[$0] as! NSManagedObject }.forEach(viewContext.delete)
                            
                            self.currentPoint = nil
                            self.currentPoint = currentPoint
                            currentShape = nil
                            do {
                                try viewContext.save()
                            } catch {
                                let nsError = error as NSError
                                print("Cannot delete shapes", nsError)
                            }
                        })
                    //}
                }
            }
            .tabItem {
                Image(systemName: "cube.fill")
                Text("Shapes")
            }
        }
        .frame(alignment: .topLeading)
         */
        
        .toolbar {
            
            ToolbarItemGroup(placement: .automatic) {
                
                Button(action: {
                    modelIconColor = .accentColor
                    renderIconColor = .secondary
                    project.render = false
                    save("")
                    model.renderer?.performRestart()
                }) {
                    Text("MODEL")
                }
                .foregroundColor(modelIconColor)
                .buttonStyle(.borderless)

                Button(action: {
                    modelIconColor = .secondary
                    renderIconColor = .accentColor
                    project.render = true
                    save("")
                    model.renderer?.performRestart()
                }) {
                    Text("RENDER")
                }
                .foregroundColor(renderIconColor)
                .buttonStyle(.borderless)                
            }
            
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
            }
            
            ToolbarItemGroup(placement: .automatic) {
                
                Button(action: {
                    pointIconColor = .accentColor
                    lineIconColor = .secondary
                }) {
                    Label("Points", systemImage: "circle.fill")
                        .imageScale(.large)
                }
                .foregroundColor(pointIconColor)
                .buttonStyle(.borderless)
                
                Button(action: {
                    pointIconColor = .secondary
                    lineIconColor = .accentColor
                }) {
                    Label("Lines", systemImage: "line.diagonal")
                        .imageScale(.large)
                }
                .foregroundColor(lineIconColor)
                .buttonStyle(.borderless)
            }
        }
        
        .onReceive(model.projectChanged) { project in
            if project?.render == true {
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
    
        .onReceive(self.model.pointChanged) { point in
            self.selectedPoint = point
        }
    }
    
    func save(_ text: String) {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print(text, nsError)
        }
    }
}
