// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "LendicgramVK",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "LendicgramVK",
            targets: ["AppModule"],
            bundleIdentifier: "com.lendic.LendicgramVK",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait
            ],
            capabilities: [
                .microphone(purposeString: "Нужен для голосовых и видеосообщений"),
                .camera(purposeString: "Нужна для отправки фото и видеосообщений")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "LendicgramVK/LendicgramVK",
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
