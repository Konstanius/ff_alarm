package de.jena.feuerwehr.app;

import androidx.annotation.NonNull;
import androidx.core.app.ServiceCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.app.ActivityManager;
import android.app.Notification;
import android.app.Service;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build.VERSION;
import android.os.Build.VERSION_CODES;

import android.net.ConnectivityManager;
import android.provider.Settings;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "app.feuerwehr.jena.de/methods";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            switch (call.method) {
                                case "backgroundData":
                                    result.success(getBackgroundDataEnabled());
                                    break;
                                case "startGeofenceService":
                                    try {
                                        Intent intent = new Intent(this, de.jena.feuerwehr.app.GeofenceService.class);
                                        ContextCompat.startForegroundService(getApplicationContext(), intent);
                                        result.success(true);
                                    } catch (Exception e) {
                                        System.out.println(e.getMessage());
                                        e.printStackTrace();
                                        result.error("Service Error", e.getMessage(), null);
                                    }
                                    break;
                                case "checkGeofenceService":
                                    Context context = getApplicationContext();
                                    ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
                                    for (ActivityManager.RunningServiceInfo service : activityManager.getRunningServices(Integer.MAX_VALUE)) {
                                        if (de.jena.feuerwehr.app.GeofenceService.class.getName().equals(service.service.getClassName())) {
                                            result.success(true);
                                            return;
                                        }
                                    }
                                    result.success(false);
                                    break;
                                case "stopGeofenceService":
                                    try {
                                        Intent intent = new Intent(this, de.jena.feuerwehr.app.GeofenceService.class);
                                        stopService(intent);
                                        result.success(true);
                                    } catch (Exception e) {
                                        result.error("Service Error", e.getMessage(), null);
                                    }
                                    break;
                                default:
                                    result.notImplemented();
                                    break;
                            }
                        }
                );
    }

    private boolean getBackgroundDataEnabled() {
        if (VERSION.SDK_INT < VERSION_CODES.N) {
            return true;
        }

        ConnectivityManager cm = (ConnectivityManager) getSystemService(ContextWrapper.CONNECTIVITY_SERVICE);
        boolean backgroundData = cm.getBackgroundDataSetting();
        boolean restrictBackground = cm.getRestrictBackgroundStatus() == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED;
        return backgroundData && !restrictBackground;
    }
}