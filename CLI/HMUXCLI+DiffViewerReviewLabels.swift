import Foundation

extension HMUXCLI.DiffViewerLabels {
    /// Labels for the review-parity controls (viewed state, file filter,
    /// generated and large-diff collapse). Kept out of `hmux_open.swift`,
    /// which is over the file length budget; `localized()` merges them.
    static var reviewParityLabels: [String: String] {
        [
            "changedSinceViewed": HMUXDiffViewerLocalization.string("diffViewer.changedSinceViewed", defaultValue: "Changed since viewed"),
            "clearFileFilter": HMUXDiffViewerLocalization.string("diffViewer.clearFileFilter", defaultValue: "Clear filter"),
            "filesViewedProgress": HMUXDiffViewerLocalization.string("diffViewer.filesViewedProgress", defaultValue: "{viewed} of {total} files viewed"),
            "filterAddedFiles": HMUXDiffViewerLocalization.string("diffViewer.filterAddedFiles", defaultValue: "Added"),
            "filterDeletedFiles": HMUXDiffViewerLocalization.string("diffViewer.filterDeletedFiles", defaultValue: "Deleted"),
            "filterFiles": HMUXDiffViewerLocalization.string("diffViewer.filterFiles", defaultValue: "Filter files"),
            "filterModifiedFiles": HMUXDiffViewerLocalization.string("diffViewer.filterModifiedFiles", defaultValue: "Modified"),
            "filterRenamedFiles": HMUXDiffViewerLocalization.string("diffViewer.filterRenamedFiles", defaultValue: "Renamed"),
            "generatedFile": HMUXDiffViewerLocalization.string("diffViewer.generatedFile", defaultValue: "Generated file"),
            "hideViewedFiles": HMUXDiffViewerLocalization.string("diffViewer.hideViewedFiles", defaultValue: "Hide viewed files"),
            "largeDiff": HMUXDiffViewerLocalization.string("diffViewer.largeDiff", defaultValue: "Large diff"),
            "loadDiff": HMUXDiffViewerLocalization.string("diffViewer.loadDiff", defaultValue: "Load diff"),
            "markNotViewed": HMUXDiffViewerLocalization.string("diffViewer.markNotViewed", defaultValue: "Mark as not viewed"),
            "markViewed": HMUXDiffViewerLocalization.string("diffViewer.markViewed", defaultValue: "Mark as viewed"),
            "noFilesMatchFilter": HMUXDiffViewerLocalization.string("diffViewer.noFilesMatchFilter", defaultValue: "No files match the filter."),
            "showViewedFiles": HMUXDiffViewerLocalization.string("diffViewer.showViewedFiles", defaultValue: "Show viewed files"),
            "viewed": HMUXDiffViewerLocalization.string("diffViewer.viewed", defaultValue: "Viewed"),
        ]
    }
}
