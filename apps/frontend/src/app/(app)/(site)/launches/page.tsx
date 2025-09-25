export const dynamic = 'force-dynamic';
import { LaunchesComponent } from '@gitroom/frontend/components/launches/launches.component';
import { Metadata } from 'next';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';
export const metadata: Metadata = {
  title: 'My Content Generator - AI-Powered Content Studio',
  description: 'Create, schedule, and manage your content with AI-powered tools',
};
export default async function Index() {
  return <LaunchesComponent />;
}
