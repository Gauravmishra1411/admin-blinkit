importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBoq7eFVsY8zQ7wbKtvQ1fW7Ka-Qr6b26c",
  appId: "1:195949054113:web:26638dc9f8615f58ab08e0",
  messagingSenderId: "195949054113",
  projectId: "demoproject-87d37",
  authDomain: "demoproject-87d37.firebaseapp.com",
  storageBucket: "demoproject-87d37.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message (Admin) ", payload);
  const notificationTitle = payload.notification.title || "New Admin Notification";
  const notificationOptions = {
    body: payload.notification.body || "Check the dashboard for details.",
    icon: "/favicon.png",
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
