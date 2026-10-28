import Testing
import HmuxTerminalCore
import GhosttyKit

@Suite struct SurfaceConfigTemplateFontSizeTests {
    @Test func freshFontSizeAssignmentClaimsExplicitOwnership() {
        var template = HmuxSurfaceConfigTemplate()

        template.fontSize = 13

        #expect(template.fontSizeLineage == TerminalFontSizeLineage(
            basePoints: 13,
            isExplicitOverride: true
        ))
    }

    @Test func inheritedCConfigFontSizeRemainsNonExplicit() {
        var cConfig = ghostty_surface_config_s()
        cConfig.font_size = 24

        let template = HmuxSurfaceConfigTemplate(
            cConfig: cConfig,
            globalFontMagnificationPercent: 200
        )

        #expect(template.fontSizeLineage == TerminalFontSizeLineage(
            basePoints: 12,
            isExplicitOverride: false
        ))
    }

    @Test func convertsRuntimeFontSizeToBasePoints() {
        let basePoints = HmuxSurfaceConfigTemplate.baseFontSize(fromRuntimePoints: 24, percent: 200)

        #expect(abs(basePoints - 12) < 0.001)
    }

    @Test func convertsBaseFontSizeToRuntimePoints() {
        let runtimePoints = HmuxSurfaceConfigTemplate.runtimeFontSize(fromBasePoints: 12, percent: 200)

        #expect(abs(runtimePoints - 24) < 0.001)
    }

    @Test(arguments: [50, 100, 200])
    func runtimeDefaultFontSizePreservesZeroSentinel(percent: Int) {
        let defaultBasePoints = HmuxSurfaceConfigTemplate().fontSize

        #expect(defaultBasePoints == 0)
        #expect(
            HmuxSurfaceConfigTemplate.runtimeFontSize(
                fromBasePoints: defaultBasePoints,
                percent: percent
            ) == 0
        )
        #expect(
            HmuxSurfaceConfigTemplate.runtimeFontSize(
                fromBasePoints: 0,
                percent: percent
            ) == 0
        )
    }

    @Test(arguments: [50, 100, 200])
    func invalidBaseFontSizeUsesRuntimeDefaultSentinel(percent: Int) {
        let invalidBasePoints: [Float32] = [
            -1,
            .nan,
            .infinity,
            -.infinity,
        ]

        for basePoints in invalidBasePoints {
            #expect(
                HmuxSurfaceConfigTemplate.runtimeFontSize(
                    fromBasePoints: basePoints,
                    percent: percent
                ) == 0
            )
        }
    }

    @Test func inheritedRuntimeFontSizeRoundTripsWithoutCompounding() {
        let basePoints = HmuxSurfaceConfigTemplate.baseFontSize(fromRuntimePoints: 24, percent: 200)
        let runtimePoints = HmuxSurfaceConfigTemplate.runtimeFontSize(fromBasePoints: basePoints, percent: 200)

        #expect(abs(runtimePoints - 24) < 0.001)
    }

    @Test func retainsExplicitFontSizeOwnershipWhileChangingPoints() {
        var template = HmuxSurfaceConfigTemplate()
        template.setFontSize(9, isExplicitOverride: true)

        template.fontSize = 11

        #expect(template.fontSizeLineage == TerminalFontSizeLineage(
            basePoints: 11,
            isExplicitOverride: true
        ))
    }

    @Test func invalidFontSizeClearsLineage() {
        var template = HmuxSurfaceConfigTemplate()
        template.setFontSize(9, isExplicitOverride: true)

        template.fontSize = 0

        #expect(template.fontSizeLineage == nil)
    }

    @Test(arguments: [Float32(511), Float32.greatestFiniteMagnitude])
    func oversizedFontSizeClearsLineage(basePoints: Float32) {
        var propertyTemplate = HmuxSurfaceConfigTemplate()
        propertyTemplate.fontSize = basePoints

        var methodTemplate = HmuxSurfaceConfigTemplate()
        methodTemplate.setFontSize(basePoints, isExplicitOverride: true)

        #expect(propertyTemplate.fontSizeLineage == nil)
        #expect(methodTemplate.fontSizeLineage == nil)
    }

    @Test func maximumPersistableBaseFontSizeIsAccepted() {
        var template = HmuxSurfaceConfigTemplate()

        template.setFontSize(510, isExplicitOverride: true)

        #expect(template.fontSizeLineage == TerminalFontSizeLineage(
            basePoints: 510,
            isExplicitOverride: true
        ))
    }

    @Test func runtimeFontSizeClampsToGhosttyMaximumAtIncreasedMagnification() {
        let runtimePoints = HmuxSurfaceConfigTemplate.runtimeFontSize(
            fromBasePoints: 510,
            percent: 200
        )

        #expect(runtimePoints == 255)
    }

    @Test func maximumRuntimeFontConvertsToMaximumPersistableBaseAtMinimumMagnification() {
        let basePoints = HmuxSurfaceConfigTemplate.baseFontSize(
            fromRuntimePoints: 255,
            percent: 50
        )

        #expect(basePoints == 510)
    }

    @Test func minimumRuntimeFontRoundTripsAtIncreasedMagnification() {
        let basePoints = HmuxSurfaceConfigTemplate.baseFontSize(
            fromRuntimePoints: 1,
            percent: 200
        )
        let restoredRuntimePoints = HmuxSurfaceConfigTemplate.runtimeFontSize(
            fromBasePoints: basePoints,
            percent: 200
        )

        #expect(basePoints == 0.5)
        #expect(restoredRuntimePoints == 1)
    }

    @Test func withoutStartupWorkKeepsDisplayConfiguration() {
        var template = HmuxSurfaceConfigTemplate()
        template.fontSize = 15
        template.workingDirectory = "/tmp/project"
        template.command = "agent --resume"
        template.environmentVariables = ["PROJECT": "hmux"]
        template.initialInput = "resume\r"
        template.waitAfterCommand = true

        let sanitized = template.withoutStartupWork()

        #expect(sanitized.fontSize == template.fontSize)
        #expect(sanitized.workingDirectory == template.workingDirectory)
        #expect(sanitized.environmentVariables == template.environmentVariables)
        #expect(sanitized.command == nil)
        #expect(sanitized.initialInput == nil)
        #expect(!sanitized.waitAfterCommand)
    }
}
