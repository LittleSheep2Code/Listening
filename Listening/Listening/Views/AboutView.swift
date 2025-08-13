
import SwiftUI

struct AboutView: View {
    @State private var currentIconName = UIApplication.shared.alternateIconName;
    @State private var didError = false;
    @State private var detailsError: Error?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack(alignment: .bottom, spacing: 20) {
                    let displayIconName = currentIconName == nil ? "Logo" : "Logo Original";
                    
                    Image(displayIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .cornerRadius(20)
                    
                    let nextIconDisplayName = currentIconName == nil ? "NightSystem" : "LittleSheep";
                    
                    Button(action: {
                        UIApplication.shared.setAlternateIconName(
                            currentIconName == nil ? "AppIcon Original" : nil,
                            completionHandler: { err in
                                currentIconName = UIApplication.shared.alternateIconName
                                didError = err != nil
                                detailsError = err
                            }
                        )
                    }) {
                        Label("使用 \(nextIconDisplayName) 的图标", systemImage: "arrow.clockwise")
                    }
                    .padding(.bottom, 8)
                    .alert(
                        "无法改变应用图标",
                        isPresented: $didError,
                        presenting: detailsError
                    ) { _ in } message: { details in
                        Text(detailsError!.localizedDescription)
                    }
                }.padding(.bottom, 20)
                
                Text("聆听")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("一个简单的本地音乐播放器，仅此而已")
                    .font(.subheadline)
                    .padding(.bottom, 5)
                
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(appVersion)")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Link("GitHub Repo",
                     destination: URL(string: "https://github.com/littlesheep/listening")!)
                .padding(.top, 10)
                
                Text("NightSystem")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                Link("GitHub",
                     destination: URL(string: "https://github.com/night-system")!)
                Link("Solar Network Profile", destination: URL(string: "https://id.solian.app/@NightSystem")!)
                
                Text("LittleSheep")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                Link("GitHub",
                     destination: URL(string: "https://github.com/littlesheep2code")!)
                Link("Solar Network Profile", destination: URL(string: "https://id.solian.app/@littlesheep")!)
                
                Text("Other work from LittleSheep")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                Link("The Solar Network",
                     destination: URL(string: "https://solsynth.dev/products/solar-network")!)
                
                Text("Original work by NightSystem.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                Text("Modified by LittleSheep.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("© 2025 NightSystem & LittleSheep. All rights reserved.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
            .navigationTitle("About")
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
