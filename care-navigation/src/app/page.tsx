import Header from "@/components/Header";
import HeroSection from "@/components/HeroSection";
import ProblemSection from "@/components/ProblemSection";
import HowItWorksSection from "@/components/HowItWorksSection";
import RouteComparisonDemo from "@/components/RouteComparisonDemo";
import FeatureSection from "@/components/FeatureSection";
import TechnologySection from "@/components/TechnologySection";
import BetaSection from "@/components/BetaSection";
import FAQSection from "@/components/FAQSection";
import FinalCTA from "@/components/FinalCTA";
import Footer from "@/components/Footer";
import MobileStickyCTA from "@/components/MobileStickyCTA";

export default function Home() {
  return (
    <div id="top">
      <Header />
      <main>
        <HeroSection />
        <ProblemSection />
        <HowItWorksSection />
        <RouteComparisonDemo />
        <FeatureSection />
        <TechnologySection />
        <BetaSection />
        <FAQSection />
        <FinalCTA />
      </main>
      <Footer />
      <MobileStickyCTA />
    </div>
  );
}
