//
//  ContentView.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var model                               : Model

    @ObservedObject var currProject         : Project = Project()
    
    @State var updateView                   : Bool = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Project.index, ascending: true)],
        animation: .default)
    
    private var projects                    : FetchedResults<Project>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Material.index, ascending: true)],
        animation: .default)
    
    private var materials                   : FetchedResults<Material>

    @State private var addPopover           : Bool = false

    var body: some View {
        
        NavigationView {
            
            List {
                ForEach(projects) { project in
                    NavigationLink {
                        SceneView(model: model, project: project)
                    } label: {
                        Text(project.name!)
                    }
                }
                .onDelete(perform: deleteProjects)
                
                ForEach(materials) { material in
                    NavigationLink {
                        //MainView(model: model, project: project)
                    } label: {
                        Text(material.name!)
                    }
                }
                .onDelete(perform: deleteMaterials)
            }
                        
            #if os(iOS)
            .listStyle(PlainListStyle())
            #endif
            .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            #endif
                ToolbarItemGroup {
                    Button(action: {
                        newProject()
                    }) {
                        Label("New Scene", systemImage: "plus")
                    }
                    Button(action: {
                        newMaterial()
                    }) {
                        Label("New Scene", systemImage: "swatchpalette")
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onReceive(model.projectChanged) { project in
            model.currProject = project
            model.build()
        }
        .onReceive(model.rebuild) { _ in
            model.build()
            model.renderer?.restart()
        }
    }

    private func newProject() {
        withAnimation {
            
            let newProject = Project(context: viewContext)
            newProject.name = "New Scene"
            newProject.id = UUID()
            newProject.showPoints = true
            newProject.showShapes = true
            newProject.render = false

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Cannot create project", nsError)
            }
        }
    }
    
    private func newMaterial() {
        withAnimation {
            
            let newMaterial = Material(context: viewContext)
            newMaterial.name = "New Material"
            newMaterial.id = UUID()
            newMaterial.red = 0.5
            newMaterial.green = 0.5
            newMaterial.blue = 0.5
            newMaterial.roughness = 0.5

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Cannot create project", nsError)
            }
        }
    }

    private func deleteProjects(offsets: IndexSet) {
        withAnimation {
            offsets.map { projects[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Cannot delete projects", nsError)
            }
        }
    }
    
    private func deleteMaterials(offsets: IndexSet) {
        withAnimation {
            offsets.map { materials[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Cannot delete materials", nsError)
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//    }
//}
