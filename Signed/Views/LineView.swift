//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 24/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct LineView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
        
    let model                               : Model
    var project                             : Project
    let line                                : Line
    
    @State var startPoint                   : UUID? = nil
    @State var endPoint                     : UUID? = nil

    @State private var pointStartPopover    : Bool = false
    @State private var pointEndPopover      : Bool = false

    init(model: Model, project: Project, line: Line) {
        self.model = model
        self.project = project
        self.line = line
        
        _startPoint = State(initialValue: line.startPoint)
        _endPoint = State(initialValue: line.endPoint)
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(line.name!)
                .font(.system(size: 18))
                .onTapGesture(perform: {
                    model.lineChanged.send(line)
                })
            
            HStack {
                Button(action: {
                    pointStartPopover = true
                }) {
                    Label("", systemImage: "circle.fill")
                }
                .padding(.top, 5)
                .padding(.trailing, 10)
                .imageScale(.large)
                .buttonStyle(.borderless)
                .popover(isPresented: $pointStartPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        
                        List {
                            ForEach((project.points!.allObjects as! [Point]).sorted { $0.index < $1.index } ) { point in
                                Text(point.name!)
                                    .onTapGesture {
                                        line.startPoint = point.id
                                        startPoint = point.id
                                        model.lineChanged.send(line)
                                        save("start point")
                                        model.build()
                                    }
                                    //.foregroundColor(point.id == selectedPoint?.id ? .accentColor : .secondary)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .cornerRadius(10.0)
                    }
                    .frame(width: 200, height: 400)
                }
                
                Spacer()
                
                Button(action: {
                    pointEndPopover = true
                }) {
                    Label("", systemImage: "circle.fill")
                }
                .padding(.top, 5)
                .padding(.trailing, 10)
                .imageScale(.large)
                .buttonStyle(.borderless)
                .popover(isPresented: $pointEndPopover,
                         arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading) {
                        
                        List {
                            ForEach((project.points!.allObjects as! [Point]).sorted { $0.index < $1.index } ) { point in
                                Text(point.name!)
                                    .onTapGesture {
                                        //model.pointChanged.send(point)
                                        line.endPoint = point.id
                                        endPoint = point.id
                                        model.lineChanged.send(line)
                                        save("start point")
                                        model.build()
                                    }
                                    //.foregroundColor(point.id == selectedPoint?.id ? .accentColor : .secondary)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .cornerRadius(10.0)
                    }
                    .frame(width: 200, height: 400)
                }
            }
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
        
