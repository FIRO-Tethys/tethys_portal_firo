import { useContext } from "react";
import { LandingPageHeader } from "components/layout/Header";
import CW3EFooter from "components/layout/cw3eFooter";
import {
  AppContext,
  AvailableDashboardsContext,
} from "components/contexts/Contexts";
import LayoutAlertContextProvider from "components/contexts/LayoutAlertContext";
import DashboardLayoutAlerts from "components/dashboard/DashboardLayoutAlerts";
import DashboardCard, {
  NewDashboardCard,
  NoDashboardCard,
} from "components/landingPage/DashboardCard";
import styled from "styled-components";
import Container from "react-bootstrap/Container";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/Col";

const StyledContainer = styled(Container)`
  margin-top: 1rem;
`;

const StyledRow = styled(Row)`
  justify-content: center;
`;

const StyledCol = styled(Col)`
  flex: 0;
  width: auto;
`;

const LandingPage = () => {
  const { availableDashboards } = useContext(AvailableDashboardsContext);
  const { user, tethysApp } = useContext(AppContext);

  return (
    <LayoutAlertContextProvider>
      <div className="d-flex flex-column" style={{ minHeight: "100vh" }}>
        <a href="#main-content" className="skip-link">
          Skip to main content
        </a>
        <LandingPageHeader />
        <DashboardLayoutAlerts />
        <StyledContainer
          forwardedAs="main"
          id="main-content"
          fluid
          className="landing-page flex-grow-1"
        >
          <h1 className="screen-reader-text">
            {tethysApp?.title || "Dashboards"}
          </h1>
          <StyledRow>
            {user?.username && (
              <StyledCol>
                <NewDashboardCard />
              </StyledCol>
            )}
            {availableDashboards.length > 0 &&
              availableDashboards.map((dashboardMetadata) => (
                <StyledCol key={dashboardMetadata.id}>
                  <DashboardCard {...dashboardMetadata} />
                </StyledCol>
              ))}
            {!user?.username && availableDashboards.length === 0 && (
              <StyledCol key="no-content">
                <NoDashboardCard />
              </StyledCol>
            )}
          </StyledRow>
        </StyledContainer>
        <CW3EFooter />
      </div>
    </LayoutAlertContextProvider>
  );
};

export default LandingPage;
