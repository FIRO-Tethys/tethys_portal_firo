import React, { useContext, useState } from "react";
import "./content-extra.css";
import "./styles.css";
import "./cw3e-twentysixteen.css";
import { AppContext } from "components/contexts/Contexts";
import { getTethysPortalBase } from "services/utilities";
import Container from "react-bootstrap/Container";


const TETHYS_PORTAL_BASE = getTethysPortalBase();

const Cw3eHeader = () => {
  const { tethysApp, user } = useContext(AppContext);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuToggleClassName = `menu-toggle${isMenuOpen ? " toggled-on" : ""}`;
  const menuClassName = `site-header-menu${isMenuOpen ? " toggled-on" : ""}`;
  const loginUrl = `${TETHYS_PORTAL_BASE}/accounts/login?next=${window.location.pathname}`;
  const appUrl = `${TETHYS_PORTAL_BASE}/apps/tethysdash/`;
  const appsUrl = `${TETHYS_PORTAL_BASE}/apps/`;
  const handleDropdownToggle = (event) => {
    event.preventDefault();
    const button = event.currentTarget;
    const isExpanded = button.getAttribute("aria-expanded") === "true";
    button.setAttribute("aria-expanded", (!isExpanded).toString());
    button.classList.toggle("toggled-on");
    const submenu = button.nextElementSibling;
    if (submenu) {
      submenu.classList.toggle("toggled-on");
    }
  };

  return (
        <Container fluid className="px-5">
            <div className="header-image" style={{ position: "relative"}}>
                <a
                    href="https://cw3e.ucsd.edu/"
                    rel="home"
                    style={{ width: "100%", justifyContent: "center" }}
                >
                    <img
                        src="https://cw3e.ucsd.edu/wp-content/uploads/2024/08/header_finalv2.png"
                        style={{ width: "100%" }}
                        srcSet="https://cw3e.ucsd.edu/wp-content/uploads/2024/08/header_finalv2-300x32.png 300w, https://cw3e.ucsd.edu/wp-content/uploads/2024/08/header_finalv2-1024x110.png 1024w, https://cw3e.ucsd.edu/wp-content/uploads/2024/08/header_finalv2-768x83.png 768w, https://cw3e.ucsd.edu/wp-content/uploads/2024/08/header_finalv2.png 1200w"
                        height="129"
                        alt="CW3E Header Logo"
                    />
                </a>
            </div>

            <div className="site-header-main" style={{ maxWidth: "100%" }}>
                <button
                    id="menu-toggle"
                    className={menuToggleClassName}
                    type="button"
                    aria-controls="site-header-menu"
                    aria-expanded={isMenuOpen}
                    onClick={() => setIsMenuOpen((prev) => !prev)}
                >
                    Menu
                </button>

                <div
                    id="site-header-menu"
                    className={menuClassName}
                    style={{ width: "100%"}}
                >
                    <nav
                        id="site-navigation"
                        className="main-navigation"
                        role="navigation"
                        aria-label="Primary Menu"
                        style={{ border: "none"}}
                    >
                        <div className="menu-main-menu-container">
                            <ul id="menu-main-menu" className="primary-menu">
                                <li
                                    id="menu-item-25357"
                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25357"
                                    aria-haspopup="true"
                                >
                                    <a href="https://cw3e.ucsd.edu/overview/">About</a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25358"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25358"
                                        >
                                            <a href="https://cw3e.ucsd.edu/overview/">Overview</a>
                                        </li>
                                        <li
                                            id="menu-item-25349"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-25349"
                                        >
                                            <a href="https://cw3e.ucsd.edu/wp-content/uploads/CW3E_Strategic_Plan_2025.pdf">
                                                CW3E Strategic Plan
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25359"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25359"
                                        >
                                            <a href="https://cw3e.ucsd.edu/background/">Background</a>
                                        </li>
                                        <li
                                            id="menu-item-25363"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25363"
                                        >
                                            <a href="https://cw3e.ucsd.edu/themes/">Themes</a>
                                        </li>
                                        <li
                                            id="menu-item-25361"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25361"
                                        >
                                            <a href="https://cw3e.ucsd.edu/people/">People</a>
                                        </li>
                                        <li
                                            id="menu-item-25360"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25360"
                                        >
                                            <a href="https://cw3e.ucsd.edu/partners/">Partners</a>
                                        </li>
                                        <li
                                            id="menu-item-25362"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25362"
                                        >
                                            <a href="https://cw3e.ucsd.edu/programs-2/">Programs</a>
                                        </li>
                                        <li
                                            id="menu-item-25373"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25373"
                                        >
                                            <a href="https://cw3e.ucsd.edu/edi/">
                                                Equity, Diversity, &amp; Inclusion (EDI)
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25947"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25947"
                                        >
                                            <a href="https://cw3e.ucsd.edu/donate/">Donate</a>
                                        </li>
                                        <li
                                            id="menu-item-25372"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25372"
                                        >
                                            <a href="https://cw3e.ucsd.edu/water-affiliates-group/">
                                                Water Affiliates Group
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25354"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-25354"
                                        >
                                            <a href="https://www.youtube.com/watch?v=NULrvr8pTBg&amp;feature=emb_logo">
                                                What is an Atmospheric River?
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25406"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25406"
                                        >
                                            <a href="https://cw3e.ucsd.edu/dec2022-jan2023_arstorymap/">
                                                WY 2023 AR Family Story Map
                                            </a>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25347"
                                    className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-25347"
                                    aria-haspopup="true"
                                >
                                    <a href="#">Observations</a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25356"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-25356"
                                            aria-haspopup="true"
                                        >
                                            <a href="#">CW3E Observations</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-25410"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25410"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e_observations_surfacemet/">
                                                        Surface Meteorology
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-25412"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25412"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e_observations_mrrs/">
                                                        MicroRain Radars
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-25411"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25411"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e_observations_disdrometers/">
                                                        Disdrometers
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-25413"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25413"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e_observations_wind_profilers/">
                                                        Wind Profilers
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-25414"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25414"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e_radiosondes/">
                                                        Radiosondes
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-26699"
                                                    className="menu-item menu-item-type-custom menu-item-object-custom menu-item-26699"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/metadata/sites/">
                                                        Site Information
                                                    </a>
                                                </li>
                                            </ul>
                                        </li>
                                        <li
                                            id="menu-item-25379"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25379"
                                        >
                                            <a href="https://cw3e.ucsd.edu/satellite/">Satellite</a>
                                        </li>
                                        <li
                                            id="menu-item-25366"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25366"
                                        >
                                            <a href="https://cw3e.ucsd.edu/precipitation-observations/">
                                                Precipitation
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25417"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25417"
                                        >
                                            <a href="https://cw3e.ucsd.edu/water_storage_tracking/">
                                                Water Storage Tracking
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25365"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25365"
                                        >
                                            <a href="https://cw3e.ucsd.edu/riverflow/">Stream Flow</a>
                                        </li>
                                        <li
                                            id="menu-item-25364"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25364"
                                        >
                                            <a href="https://cw3e.ucsd.edu/real-time-observations/">
                                                AR Observatories
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25415"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25415"
                                        >
                                            <a href="https://cw3e.ucsd.edu/aqpi/">AQPI</a>
                                        </li>
                                        <li
                                            id="menu-item-26834"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-26834"
                                        >
                                            <a href="https://cw3e.ucsd.edu/Projects/ARCatalog/catalog.html">
                                                AR Landfall Catalog
                                            </a>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25382"
                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25382"
                                    aria-haspopup="true"
                                >
                                    <a href="https://cw3e.ucsd.edu/arrecon_overview/">
                                        AR Reconnaissance
                                    </a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25384"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25384"
                                        >
                                            <a href="https://cw3e.ucsd.edu/arrecon_overview/">Overview</a>
                                        </li>
                                        <li
                                            id="menu-item-25383"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25383"
                                        >
                                            <a href="https://cw3e.ucsd.edu/arrecon_data/">Data</a>
                                        </li>
                                        <li
                                            id="menu-item-25385"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25385"
                                        >
                                            <a href="https://cw3e.ucsd.edu/arrecon_partners/">
                                                Sponsors &amp; Partners
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25392"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25392"
                                        >
                                            <a href="https://cw3e.ucsd.edu/arrecon_news/">Related Info</a>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25367"
                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25367"
                                    aria-haspopup="true"
                                >
                                    <a href="https://cw3e.ucsd.edu/iwv-and-ivt-forecasts/">
                                        Forecasts
                                    </a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25368"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25368"
                                        >
                                            <a href="https://cw3e.ucsd.edu/iwv-and-ivt-forecasts/">
                                                AR, IWV, and IVT Forecasts
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25398"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25398"
                                        >
                                            <a href="https://cw3e.ucsd.edu/arscale/">AR Scale Forecasts</a>
                                        </li>
                                        <li
                                            id="menu-item-25353"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-25353"
                                            aria-haspopup="true"
                                        >
                                            <a href="#">Deterministic Models</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-25397"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25397"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/ivt_iwv_nepacific/">IVT and IWV</a>
                                                </li>
                                                <li
                                                    id="menu-item-25396"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25396"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/250winds_nepac/">250-hPa Winds</a>
                                                </li>
                                                <li
                                                    id="menu-item-25395"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25395"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/500vort_nepac/">500-hPa Vorticity</a>
                                                </li>
                                                <li
                                                    id="menu-item-25394"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25394"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/850temp_nepac/">850-hPa Temperature</a>
                                                </li>
                                            </ul>
                                        </li>
                                        <li
                                            id="menu-item-25351"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-25351"
                                        >
                                            <a href="https://cw3e.ucsd.edu/DSMaps/DS_intro.html">Interactive Maps</a>
                                        </li>
                                        <li
                                            id="menu-item-25369"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25369"
                                        >
                                            <a href="https://cw3e.ucsd.edu/precipitation_forecasts/">
                                                Precipitation Forecasts
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25399"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25399"
                                        >
                                            <a href="https://cw3e.ucsd.edu/s_and_s_forecasts/">
                                                Subseasonal and Seasonal Forecasts
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25401"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25401"
                                            aria-haspopup="true"
                                        >
                                            <a href="https://cw3e.ucsd.edu/west-wrf/">West-WRF</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-25404"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25404"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/west-wrf/">Deterministic</a>
                                                </li>
                                                <li
                                                    id="menu-item-25405"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25405"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/west-wrf_ensemble/">Ensemble</a>
                                                </li>
                                            </ul>
                                        </li>
                                        <li
                                            id="menu-item-26535"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-26535"
                                        >
                                            <a href="https://cw3e.ucsd.edu/ml_forecasts/">Machine Learning</a>
                                        </li>
                                        <li
                                            id="menu-item-26184"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-26184"
                                            aria-haspopup="true"
                                        >
                                            <a href="#">Forecast Verification</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-26183"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-26183"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/cw3e-atmospheric-river-landfall-met-mode-verification-tool/">
                                                        AR Landfall Verification
                                                    </a>
                                                </li>
                                                <li
                                                    id="menu-item-26185"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-26185"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/qpf_mode_verification/">QPF Verification</a>
                                                </li>
                                            </ul>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25348"
                                    className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-25348"
                                    aria-haspopup="true"
                                >
                                    <a href="/firo">FIRO</a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25388"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25388"
                                        >
                                            <a href="https://cw3e.ucsd.edu/firo/">Overview</a>
                                        </li>
                                        <li
                                            id="menu-item-25386"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25386"
                                        >
                                            <a href="https://cw3e.ucsd.edu/firo_process/">Process</a>
                                        </li>
                                        <li
                                            id="menu-item-25389"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25389"
                                        >
                                            <a href="https://cw3e.ucsd.edu/firo_news/">News</a>
                                        </li>
                                        <li
                                            id="menu-item-25408"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25408"
                                            aria-haspopup="true"
                                        >
                                            <a href="https://cw3e.ucsd.edu/firo_projects/">Projects</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-25403"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25403"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/firo_russian_river/">FIRO Russian River</a>
                                                </li>
                                                <li
                                                    id="menu-item-25387"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25387"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/firo_prado_dam/">Prado Dam</a>
                                                </li>
                                                <li
                                                    id="menu-item-25390"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25390"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/firo_yuba_feather/">Yuba-Feather</a>
                                                </li>
                                                <li
                                                    id="menu-item-25409"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25409"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/firo_seven_oaks_dam/">Seven Oaks Dam</a>
                                                </li>
                                                <li
                                                    id="menu-item-25407"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25407"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/firo_howard_hanson/">Howard Hanson Dam</a>
                                                </li>
                                            </ul>
                                        </li>
                                        <li
                                            id="menu-item-25355"
                                            className="menu-item menu-item-type-custom menu-item-object-custom menu-item-25355"
                                        >
                                            <a href="/firo_colloquium_2021/">FIRO Colloquium</a>
                                        </li>
                                        <li
                                            id="menu-item-27218"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-27218"
                                        >
                                            <a href="https://cw3e.ucsd.edu/firo_workshop_2025/">FIRO Workshop</a>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25350"
                                    className="menu-item menu-item-type-custom menu-item-object-custom menu-item-has-children menu-item-25350"
                                    aria-haspopup="true"
                                >
                                    <a href="#">News &amp; Publications</a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25378"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25378"
                                        >
                                            <a href="https://cw3e.ucsd.edu/news/">News</a>
                                        </li>
                                        <li
                                            id="menu-item-25375"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25375"
                                            aria-haspopup="true"
                                        >
                                            <a href="https://cw3e.ucsd.edu/publications/">Publications</a>
                                            <button
                                                className="dropdown-toggle" onClick={handleDropdownToggle}
                                                aria-expanded="false"
                                                type="button"
                                            >
                                                <span className="screen-reader-text">
                                                    expand child menu
                                                </span>
                                            </button>
                                            <ul className="sub-menu">
                                                <li
                                                    id="menu-item-25374"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25374"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/publications/">Peer Reviewed Articles</a>
                                                </li>
                                                <li
                                                    id="menu-item-25370"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25370"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/booksbook-chapters/">Book Chapters</a>
                                                </li>
                                                <li
                                                    id="menu-item-25371"
                                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25371"
                                                >
                                                    <a href="https://cw3e.ucsd.edu/public-reports/">Public Reports</a>
                                                </li>
                                            </ul>
                                        </li>
                                        <li
                                            id="menu-item-25402"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25402"
                                        >
                                            <a href="https://cw3e.ucsd.edu/ar_publications/">
                                                Bibliography of AR-Focused Publications
                                            </a>
                                        </li>
                                        <li
                                            id="menu-item-25377"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25377"
                                        >
                                            <a href="https://cw3e.ucsd.edu/meetings/">Meetings</a>
                                        </li>
                                        <li
                                            id="menu-item-25391"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25391"
                                        >
                                            <a href="https://cw3e.ucsd.edu/iarc/">International Atmospheric Rivers Conference</a>
                                        </li>
                                        <li
                                            id="menu-item-25400"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25400"
                                        >
                                            <a href="https://cw3e.ucsd.edu/cw3e-internship-program/">Summer Internship Program</a>
                                        </li>
                                    </ul>
                                </li>

                                <li
                                    id="menu-item-25376"
                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25376"
                                >
                                    <a href="https://cw3e.ucsd.edu/cw3e-north-sonoma-county-water-agency/">
                                        CW3E North
                                    </a>
                                </li>
                                <li
                                    id="menu-item-25382"
                                    className="menu-item menu-item-type-post_type menu-item-object-page menu-item-has-children menu-item-25382"
                                    aria-haspopup="true"
                                >
                                    <a href={appsUrl}>
                                        Web Applications
                                    </a>
                                    <button
                                        className="dropdown-toggle" onClick={handleDropdownToggle}
                                        aria-expanded="false"
                                        type="button"
                                    >
                                        <span className="screen-reader-text">expand child menu</span>
                                    </button>
                                    <ul className="sub-menu">
                                        <li
                                            id="menu-item-25384"
                                            className="menu-item menu-item-type-post_type menu-item-object-page menu-item-25384"
                                        >
                                            <a href={appUrl}>TethysDash</a>
                                        </li>
                                        {user?.isStaff && (
                                            <li className="menu-item menu-item-type-custom menu-item-object-custom">
                                                <a href={tethysApp?.settingsUrl}>Settings</a>
                                            </li>
                                        )}
                                        {!user?.username && (
                                            <li className="menu-item menu-item-type-custom menu-item-object-custom">
                                                <a href={loginUrl}>Login</a>
                                            </li>
                                        )}
                                        <li className="menu-item menu-item-type-custom menu-item-object-custom">
                                            <a href={tethysApp?.exitUrl}>Logout</a>
                                        </li>
                                    </ul>
                                </li>

                            </ul>
                        </div>
                    </nav>
                </div>
            </div>
        </Container>
    );
};

export default Cw3eHeader;