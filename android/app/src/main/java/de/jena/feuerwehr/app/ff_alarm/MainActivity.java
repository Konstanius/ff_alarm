package de.jena.feuerwehr.app;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

// Platform Channel imports
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build.VERSION;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;

// ConnectivityManager for background data
import android.net.ConnectivityManager;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "app.feuerwehr.jena.de/methods";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("backgroundData")) {
                                result.success(getBackgroundDataEnabled());
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private boolean getBackgroundDataEnabled() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(ContextWrapper.CONNECTIVITY_SERVICE);
        boolean backgroundData = cm.getBackgroundDataSetting();
        boolean restrictBackground = cm.getRestrictBackgroundStatus() == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED;
        return backgroundData && !restrictBackground;
    }
}