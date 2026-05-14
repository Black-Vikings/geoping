import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export const onSessionStarted = onDocumentUpdated(
  'sessions/{configId}',
  async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();

    // Only fire when transitioning from inactive to active
    if (!after?.active || before?.active) return;

    const configSnap = await getFirestore()
      .doc(`configs/${event.params.configId}`)
      .get();
    const config = configSnap.data();
    const tokens: string[] = config?.fcmTokens ?? [];
    if (!tokens.length) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'GeoPing 📍',
        body: `${config?.elderName ?? 'Tu familiar'} está compartiendo su ubicación`,
      },
      data: { configId: event.params.configId },
      android: { priority: 'high' },
      apns: { payload: { aps: { contentAvailable: true } } },
    });
  }
);
