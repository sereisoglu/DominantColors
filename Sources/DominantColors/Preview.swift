//
//  Preview.swift
//
//
//  Created by Denis Dmitriev on 21.04.2024.
//

import SwiftUI

@available(macOS 14.0, *)
struct Preview: View {
    
    private static let images = ["WaterLife", "ComeTogether", "TestPaletteSize"]
    @State private var selection: String = Self.images.first ?? ""
    @State private var nsImage: NSImage?
    @State private var cgImage: CGImage?
    @State private var cgImageSize: NSSize = .zero
    @State private var colors = [Color]()
    @State private var sorting: DominantColors.Sort = .frequency
    @State private var method: DeltaEFormula = .CIE76
    @State private var pureBlack: Bool = true
    @State private var pureWhite: Bool = true
    @State private var pureGray: Bool = true
    @State private var deltaColor: Int = 10
    
    var body: some View {
        VStack {
            // Image group
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(.separator)
                    Group {
                        if let nsImage {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            placeholderImage
                        }
                    }
                    .overlay(alignment: .bottom) {
                        HStack {
                            ForEach(Preview.images, id: \.self) { nameImage in
                                Circle()
                                    .fill(nameImage == selection ? .blue : .gray)
                                    .frame(width: 5)
                                    .onTapGesture {
                                        selection = nameImage
                                    }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            Capsule()
                                .fill(.background)
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .onChange(of: selection) { newSelection in
                        loadImage(newSelection)
                    }
                }
                
                HStack(spacing: 3) {
                    if !colors.isEmpty, nsImage != nil {
                        ForEach(Array(zip(colors.indices, colors)), id: \.0) { index, color in
                            Rectangle()
                                .fill(color)
                        }
                    } else {
                        if nsImage != nil {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .padding(3)
                .background(.separator)
                .onChange(of: nsImage) { newImage in
                    refreshColors(from: newImage)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
            }
            
            // Setting group
            VStack {
                HStack(spacing: 16) {
                    Picker("Sorting", selection: $sorting) {
                        ForEach(DominantColors.Sort.allCases) { sorting in
                            Text(sorting.name)
                                .tag(sorting)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 160)
                    .onChange(of: sorting) { _ in
                        refreshColors(from: nsImage)
                    }
                    
                    Picker("Method", selection: $method) {
                        ForEach(DeltaEFormula.allCases) { method in
                            Text(method.method)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: method) { _ in
                        refreshColors(from: nsImage)
                    }
                    .frame(maxWidth: 160)
                    
                    HStack {
                        Text("Color Delta")
                        TextField("Delta", value: $deltaColor, format: .number)
                            .frame(width: 40)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 24) {
                    Toggle("Pure black", isOn: $pureBlack)
                        .onChange(of: pureBlack) { _ in
                            refreshColors(from: nsImage)
                        }
                    
                    Toggle("Pure white", isOn: $pureWhite)
                        .onChange(of: pureWhite) { _ in
                            refreshColors(from: nsImage)
                        }
                    
                    Toggle("Pure gray", isOn: $pureGray)
                        .onChange(of: pureGray) { _ in
                            refreshColors(from: nsImage)
                        }
                    
                    Spacer()
                }
            }
            .padding()
            
            HStack {
                Text("Colors count: \(colors.count)")
                
                Spacer()
                
                Button(action: {
                    if let nsImage {
                        refreshColors(from: nsImage)
                    }
                }, label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                })
                .disabled(colors.isEmpty)
            }
            .padding()
        }
        .onAppear {
            loadImage(selection)
        }
    }
    
    private func colorDescription(_ cgColor: CGColor) -> some View {
        VStack {
            Text("\(Int(cgColor.red255))")
            Text("\(Int(cgColor.green255))")
            Text("\(Int(cgColor.blue255))")
        }
        .foregroundStyle(Color(cgColor: cgColor.complementaryColor))
    }
    
    private var placeholderImage: some View {
        Text("No image")
            .foregroundStyle(.gray)
            .frame(height: 300)
    }
    
    private func loadImage(_ name: String) {
        let name = NSImage.Name(name)
        let nsImage = Bundle.module.image(forResource: name)
        
        DispatchQueue.main.async {
            self.nsImage = nsImage
        }
        
        if let nsImage {
            guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let targetSize = DominantColorQuality.fair.targetSize(for: cgImage.resolution)
            
            DispatchQueue.main.async {
                cgImageSize = NSSize(width: targetSize.width, height: targetSize.height)
                let resizedCGImage = cgImage.resize(to: targetSize)
                self.cgImage = resizedCGImage
            }
        }
    }
    
    private func refreshColors(from nsImage: NSImage?) {
        guard let nsImage else { return }
        
        colors.removeAll()
        
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        var flags = [DominantColors.Options]()
        if pureBlack { flags.append(.excludeBlack) }
        if pureWhite { flags.append(.excludeWhite) }
        if pureGray { flags.append(.excludeGray) }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgColors = try DominantColors.dominantColors(
                    image: cgImage,
                        quality: .fair,
                    algorithm: .iterative(formula: method),
                    maxCount: 6,
                    options: flags,
                    sorting: sorting,
                    deltaColors: CGFloat(deltaColor),
                    time: false
                )
                DispatchQueue.main.async {
                    self.colors = cgColors.map({ Color(cgColor: $0) })
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

@available(macOS 14.0, *)
#Preview {
    Preview()
        .frame(width: 600)
}
