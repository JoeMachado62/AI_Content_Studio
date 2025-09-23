import { makeId } from '@gitroom/nestjs-libraries/services/make.is';
import { google } from 'googleapis';

import { ProvidersInterface } from '@gitroom/backend/services/auth/providers.interface';
import { OAuth2Client } from 'google-auth-library/build/src/auth/oauth2client';

const clientAndYoutube = () => {
  const client = new google.auth.OAuth2({
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    redirectUri: `${process.env.FRONTEND_URL}/auth/callback/google`,
  });

  const oauth2 = (newClient: OAuth2Client) =>
    google.oauth2({
      version: 'v2',
      auth: newClient,
    });

  return { client, oauth2 };
};

export class GoogleProvider implements ProvidersInterface {
  generateLink() {
    const state = makeId(7);
    const { client } = clientAndYoutube();
    return client.generateAuthUrl({
      access_type: 'online',
      prompt: 'consent',
      state,
      scope: [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
      ],
    });
  }

  async getToken(code: string) {
    const { client } = clientAndYoutube();
    const { tokens } = await client.getToken(code);
    return tokens.access_token;
  }

  async getUser(providerToken: string) {
    const { client, oauth2 } = clientAndYoutube();
    client.setCredentials({ access_token: providerToken });
    const user = oauth2(client);
    const { data } = await user.userinfo.get();

    return {
      id: data.id!,
      email: data.email,
    };
  }
}
