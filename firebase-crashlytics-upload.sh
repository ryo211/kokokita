#!/bin/bash

# Firebase Crashlytics dSYM Upload Script
# Debug/Release両方で実行

CRASHLYTICS_SCRIPT="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"

if [ -f "$CRASHLYTICS_SCRIPT" ]; then
    echo "🔥 Uploading dSYM to Firebase Crashlytics..."
    "$CRASHLYTICS_SCRIPT"
    echo "✅ dSYM upload completed"
else
    echo "⚠️ Warning: Crashlytics upload script not found at:"
    echo "   $CRASHLYTICS_SCRIPT"
    echo "   Skipping dSYM upload."
fi
