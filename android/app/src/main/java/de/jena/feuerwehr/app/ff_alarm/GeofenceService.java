package de.jena.feuerwehr.app;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.ServiceCompat;
import androidx.core.content.ContextCompat;

import android.util.Base64;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.function.Consumer;
import java.util.zip.GZIPOutputStream;

public class GeofenceService extends Service {
    public static final int SERVICE_ID = 1;
    private HandlerThread handlerThread;
    private Handler handler;
    private boolean isRunning = false;
    private String applicationSupportDirectory;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private static void log(String message) {
        Log.d("GeofenceService", message);
    }

    @Override
    public void onCreate() {
        super.onCreate();

        applicationSupportDirectory = getApplicationInfo().dataDir + "/files";

        log("GeofenceService is starting");

        handlerThread = new HandlerThread("GeofenceServiceHandlerThread");
        handlerThread.start();
        handler = new Handler(handlerThread.getLooper());
        isRunning = true;

        updateNotification("FF Alarm Geofencing ist aktiv im Hintergrund.");

        handler.post(runnableCode);
        log("GeofenceService has started");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        Intent intent = new Intent(this, de.jena.feuerwehr.app.GeofenceService.class);
        stopService(intent);

        isRunning = false;
        locationManager.removeUpdates(locationListener);
        handler.removeCallbacks(runnableCode);
        handlerThread.quitSafely();
    }

    private void updateNotification(String body) {
        Notification.Builder notification = new Notification.Builder(this)
                .setContentTitle("FF Alarm Geofence")
                .setContentText(body)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setGroup("geofence")
                .setOngoing(true)
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setAutoCancel(false);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.setChannelId("geofence");
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notification.setAllowSystemGeneratedContextualActions(false);
        }

        int serviceCode = 0;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            serviceCode = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION;
        }

        try {
            ServiceCompat.startForeground(this, SERVICE_ID, notification.build(), serviceCode);
        } catch (Exception e) {
            log("GeofenceService failed to update notification");
            onDestroy();
        }
    }

    private boolean gpsDisabled = false;
    private boolean gpsPermissionMissing = false;

    private LocationManager locationManager = null;
    private boolean subscribedToLocationUpdates = false;

    private long lastLocationUpdate = 0;
    private long lastLocationSent = 0;
    private double lastLocationLatitude = 0;
    private double lastLocationLongitude = 0;
    private long lastFileCheck = 0;

    private final LocationListener locationListener = location -> {
        log("Location: " + location.getLatitude() + ", " + location.getLongitude());

        double distance = distance(lastLocationLatitude, lastLocationLongitude, location.getLatitude(), location.getLongitude());

        if (distance > 50) {
            log("Distance is greater than 50m, updating location");
            lastLocationUpdate = System.currentTimeMillis();
            lastLocationLatitude = location.getLatitude();
            lastLocationLongitude = location.getLongitude();
            sendUpdateToServers();
        }
    };

    private @Nullable String getFileContent(String fileName) {
        try {
            java.io.File file = new java.io.File(applicationSupportDirectory, fileName);
            if (!file.exists()) {
                return null;
            }

            java.io.FileInputStream fis = new java.io.FileInputStream(file);
            java.io.InputStreamReader isr = new java.io.InputStreamReader(fis);
            java.io.BufferedReader br = new java.io.BufferedReader(isr);

            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }

            br.close();
            isr.close();
            fis.close();

            return sb.toString();
        } catch (Exception e) {
            log("Error: " + e.getMessage());
            e.printStackTrace();
            return null;
        }
    }

    private JSONObject geofenceInfos = null;

    private static class ServerInfo {
        public String address;
        public int sessionId;
        public String token;
        public int userId;
    }

    private void sendUpdateToServers() {
        try {
            String prefsContent = getFileContent("prefs/main.json");
            if (prefsContent == null) {
                log("Error reading prefs file");
                onDestroy();
                return;
            }

            JSONObject prefs = new JSONObject(prefsContent);
            if (!prefs.has("registered_users")) {
                onDestroy();
                return;
            }

            String users = prefs.getString("registered_users");
            JSONArray usersArray = new JSONArray(users);
            ArrayList<ServerInfo> serverInfos = new ArrayList<>();
            for (int i = 0; i < usersArray.length(); i++) {
                String info = usersArray.getString(i);
                String address = info.split(" ")[0];
                int userId = Integer.parseInt(info.split(" ")[1]);

                if (!prefs.has("auth_session_" + address) || !prefs.has("auth_token_" + address)) {
                    continue;
                }

                int sessionId = prefs.getInt("auth_session_" + address);
                String token = prefs.getString("auth_token_" + address);

                ServerInfo serverInfo = new ServerInfo();
                serverInfo.address = address;
                serverInfo.sessionId = sessionId;
                serverInfo.token = token;
                serverInfo.userId = userId;

                serverInfos.add(serverInfo);
            }

            if (serverInfos.isEmpty()) {
                onDestroy();
                return;
            }

            // check for which server geofences are active
            ArrayList<ServerInfo> activeServers = new ArrayList<>();
            HashSet<String> addedAddresses = new HashSet<>();
            int enabledTotal = 0;
            int enabledActive = 0;

            for (Iterator<String> it = geofenceInfos.keys(); it.hasNext(); ) {
                String key = it.next();
                JSONObject geofence = geofenceInfos.getJSONObject(key);
                if (geofence.has("m") && geofence.getInt("m") != 1) continue;
                if (!geofence.has("e") || geofence.getInt("e") != 3) continue;
                if (!geofence.has("g") || geofence.getJSONArray("g").length() == 0) continue;

                enabledTotal++;

                JSONArray geofences = geofence.getJSONArray("g");
                for (int i = 0; i < geofences.length(); i++) {
                    String geofenceStr = geofences.getString(i);
                    String[] parts = geofenceStr.split(";");

                    double lat = Double.parseDouble(parts[0]);
                    double lon = Double.parseDouble(parts[1]);
                    long radius = Long.parseLong(parts[2]);

                    double distance = distance(lat, lon, lastLocationLatitude, lastLocationLongitude);
                    if (distance <= radius) {
                        enabledActive++;
                        break;
                    }
                }

                String address = key.split(" ")[0];
                if (addedAddresses.contains(address)) continue;

                for (ServerInfo serverInfo : serverInfos) {
                    if (serverInfo.address.equals(address)) {
                        activeServers.add(serverInfo);
                        addedAddresses.add(address);
                        break;
                    }
                }
            }

            log("Geofences active for " + enabledActive + " / " + enabledTotal + " stations");
            updateNotification("Geofences aktiv für " + enabledActive + " / " + enabledTotal + " Wachen");

            if (activeServers.isEmpty()) {
                onDestroy();
                return;
            }

            // send update to servers
            for (ServerInfo serverInfo : activeServers) {
                // POST
                // http<address>/api/personSetLocation
                String url = "http" + serverInfo.address + "/api/personSetLocation";

                // authorization: <sessionId> <token>
                String rawAuth = serverInfo.sessionId + " " + serverInfo.token;
                String auth = encode(rawAuth);

                // body: {"a":<latitude>,"o":<longitude>,"t":<nowMillis>}
                JSONObject body = new JSONObject();
                body.put("a", lastLocationLatitude);
                body.put("o", lastLocationLongitude);
                body.put("t", System.currentTimeMillis());
                String bodyStr = body.toString();

                // perform request
                URL requestUrl = new URL(url);
                HttpURLConnection connection = (HttpURLConnection) requestUrl.openConnection();
                connection.setRequestMethod("POST");
                connection.setRequestProperty("authorization", auth);

                connection.setDoOutput(true);
                connection.setUseCaches(false);

                try (DataOutputStream wr = new DataOutputStream(connection.getOutputStream())) {
                    wr.writeBytes(bodyStr);
                    wr.flush();
                }

                int responseCode = connection.getResponseCode();
                if (responseCode != 200) {
                    log("Error sending location update to " + serverInfo.address + ": " + responseCode);
                } else {
                    log("Location update sent to " + serverInfo.address);
                }
            }

            lastLocationSent = System.currentTimeMillis();
        } catch (Exception e) {
            log("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }

    public static String encode(String input) {
        try {
            byte[] utf8Bytes = input.getBytes(StandardCharsets.UTF_8);
            byte[] gzipBytes = compress(utf8Bytes);
            return Base64.encodeToString(gzipBytes, Base64.NO_WRAP);
        } catch (IOException e) {
            throw new RuntimeException("Failed to encode the string", e);
        }
    }

    private static byte[] compress(byte[] data) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        try (GZIPOutputStream gzipOutputStream = new GZIPOutputStream(byteArrayOutputStream)) {
            gzipOutputStream.write(data);
        }
        return byteArrayOutputStream.toByteArray();
    }

    // https://stackoverflow.com/questions/3694380/calculating-distance-between-two-points-using-latitude-longitude
    private static double distance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Radius of the earth

        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        double distance = R * c * 1000; // convert to meters

        distance = Math.pow(distance, 2);

        return Math.sqrt(distance);
    }

    private void removeNotification(int id) {
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(id);
    }

    private static final int gpsDisabledId = 1;
    private static final int gpsPermissionMissingId = 2;

    private final Runnable runnableCode = new Runnable() {
        @Override
        public void run() {
            if (isRunning) {
                try {
                    // check if gps permission is granted
                    if (ContextCompat.checkSelfPermission(GeofenceService.this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                        gpsPermissionMissing = true;
                        updateNotification("FF Alarm benötigt die Standortberechtigung, um Geofences zu nutzen.");
                        log("GPS permission is missing");
                        // TODO send notification

                        handler.postDelayed(this, 5000);
                        return;
                    } else if (gpsPermissionMissing) {
                        gpsPermissionMissing = false;
                        removeNotification(gpsPermissionMissingId);
                    }

                    if (locationManager == null) {
                        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
                    }
                    if (locationManager == null) {
                        updateNotification("Es besteht ein Fehler mit dem Standortdienst.");
                        log("LocationManager is null");
                        handler.postDelayed(this, 5000);
                        return;
                    }

                    // check if gps is enabled
                    if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                        gpsDisabled = true;
                        updateNotification("GPS ist deaktiviert!");
                        log("GPS is disabled");
                        // TODO send notification

                        handler.postDelayed(this, 5000);
                        return;
                    } else if (gpsDisabled) {
                        gpsDisabled = false;
                        removeNotification(gpsDisabledId);
                    }

                    if (!subscribedToLocationUpdates) {
                        locationManager.requestLocationUpdates(LocationManager.FUSED_PROVIDER, 5000, 20, locationListener);
                        subscribedToLocationUpdates = true;
                    }

                    // check if any geofences are active
                    File geofencesFile = new File(applicationSupportDirectory, "notification_settings.json");
                    if (!geofencesFile.exists()) {
                        log("Geofences file does not exist");
                        onDestroy();
                        return;
                    }

                    if (geofencesFile.lastModified() > lastFileCheck) {
                        lastFileCheck = geofencesFile.lastModified();
                        String geos = getFileContent("notification_settings.json");
                        if (geos != null) {
                            try {
                                geofenceInfos = new JSONObject(geos);
                                if (geofenceInfos.length() == 0) {
                                    log("No geofences are active");
                                    onDestroy();
                                    return;
                                }

                                boolean anyOn = false;
                                for (Iterator<String> it = geofenceInfos.keys(); it.hasNext(); ) {
                                    String key = it.next();
                                    JSONObject geofence = geofenceInfos.getJSONObject(key);
                                    if (geofence.has("m") && geofence.getInt("m") != 1) continue;
                                    if (!geofence.has("e") || geofence.getInt("e") != 3) continue;
                                    if (!geofence.has("g") || geofence.getJSONArray("g").length() == 0) continue;
                                    anyOn = true;
                                    break;
                                }

                                if (!anyOn) {
                                    // no geofences are active
                                    onDestroy();
                                    return;
                                }
                            } catch (Exception e) {
                                log("Error: " + e.getMessage());
                                e.printStackTrace();
                                onDestroy();
                                return;
                            }
                        } else {
                            log("Error reading geofences file");
                            onDestroy();
                            return;
                        }

                        lastFileCheck = System.currentTimeMillis();
                    }

                    // if last update is > 10m ago, send update
                    if (lastLocationUpdate != 0 && System.currentTimeMillis() - lastLocationSent > 10 * 60 * 1000) {
                        sendUpdateToServers();
                    }

                    handler.postDelayed(this, 5000);
                } catch (Exception e) {
                    log("Error: " + e.getMessage());
                    e.printStackTrace();
                    handler.postDelayed(this, 5000);
                }
            }
        }
    };
}
