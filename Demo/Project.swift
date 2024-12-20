import ProjectDescription

nonisolated(unsafe) let project = Project(
    name: "LoadingViewDemo",
    packages: [
        .package(path: "..")
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "MACOSX_DEPLOYMENT_TARGET": "15.0"
    ]),
    targets: [
        .target(
            name: "LoadingViewDemo",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.janodev.loadingview",
            sources: ["Sources/SwiftUI/**"],
            resources: ["Sources/Resources/**"],
            scripts: [
                swiftlintScript()
            ],
            dependencies: [
                .package(product: "LoadingView"),
            ]
        ),
        .target(
            name: "LoadingViewDemoTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.janodev.loadingview.tests",
            infoPlist: .default,
            sources: ["Tests/**"],
            resources: [],
            scripts: [
                swiftlintScript()
            ],
            dependencies: [
                .target(name: "LoadingViewDemo")
            ]
        ),
    ],
    additionalFiles: [
        "Project.swift"
    ]
)

func swiftlintScript() -> ProjectDescription.TargetScript {
    let script = """
    #!/bin/sh
    
    # Check swiftlint
    command -v /opt/homebrew/bin/swiftlint >/dev/null 2>&1 || { echo >&2 "swiftlint not found at /opt/homebrew/bin/swiftlint. Aborting."; exit 1; }

    # Create a temp file
    temp_file=$(mktemp)

    # Gather all modified and stopiced files within the Sources directory
    git ls-files -m Sources | grep ".swift$" > "${temp_file}"
    git diff --name-only --cached Sources | grep ".swift$" >> "${temp_file}"

    # Make list of unique and sorterd files
    counter=0
    for f in $(sort "${temp_file}" | uniq)
    do
        eval "export SCRIPT_INPUT_FILE_$counter=$f"
        counter=$(expr $counter + 1)
    done

    # Lint
    if [ $counter -gt 0 ]; then
        export SCRIPT_INPUT_FILE_COUNT=${counter}
        /opt/homebrew/bin/swiftlint autocorrect --use-script-input-files
    fi
    """
    return .post(script: script, name: "Swiftlint", basedOnDependencyAnalysis: false, runForInstallBuildsOnly: false, shellPath: "/bin/zsh")
}
