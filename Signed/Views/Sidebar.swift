//
//  Sidebar.swift
//  Signed
//
//  Created by Markus Moenig on 20/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import MobileCoreServices
#endif

struct Sidebar: View {
    
    @Environment(\.managedObjectContext) private var viewContext

    let model                               : Model

    @ObservedObject var project             : Project

    @State var currentPoint                 : Point? = nil

    @State var modelIconColor               : Color = .accentColor
    @State var renderIconColor              : Color = .secondary
    
    @State var pointIconColor               : Color = .accentColor
    @State var lineIconColor                : Color = .secondary
    
    @State private var pointXValue          = ""
    @State private var pointYValue          = ""
    @State private var pointZValue          = ""

    var body: some View {
        
        VStack {
            if pointIconColor == .accentColor {
                
                RenderView(model: model, mode: .Points2D)
                    .frame(width: 280, height: 280)
                
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

                    if project.points?.allObjects.count == 0 {
                        project.points = [point]
                    } else {
                        project.addToPoints(point)
                    }
                    
                    save("Cannot add point")
                }) {
                    Text("Add Point")
                }
                
                if let _ = currentPoint{
                    
                    HStack {
                        
                        TextField("X Value", text: $pointXValue)
                            .border(Color.red)
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
            } else
            if lineIconColor == .accentColor {
                Text("Line")
            }
        }
        .toolbar {
            
            ToolbarItemGroup(placement: .automatic) {
                
                Button(action: {
                    modelIconColor = .accentColor
                    renderIconColor = .secondary
                }) {
                    Text("MODEL")
                }
                .foregroundColor(modelIconColor)
                .buttonStyle(.borderless)

                Button(action: {
                    modelIconColor = .secondary
                    renderIconColor = .accentColor
                }) {
                    Text("RENDER")
                }
                .foregroundColor(renderIconColor)
                .buttonStyle(.borderless)                
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
        
        .onChange(of: pointXValue) { newValue in
            if let point = currentPoint {
                if let v = Float(newValue) {
                    point.x = v
                    save("Cannot edit point")
                }
            }
        }
        
        .onChange(of: pointYValue) { newValue in
            if let point = currentPoint {
                if let v = Float(newValue) {
                    point.y = v
                    save("Cannot edit point")
                }
            }
        }
        
        .onChange(of: pointZValue) { newValue in
            if let point = currentPoint {
                if let v = Float(newValue) {
                    point.z = v
                    save("Cannot edit point")
                }
            }
        }
        
        .onReceive(self.model.pointChanged) { point in
            self.currentPoint = point
            if let point = point {
                pointXValue = String(point.x)
                pointYValue = String(point.y)
                pointZValue = String(point.z)
            }
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
