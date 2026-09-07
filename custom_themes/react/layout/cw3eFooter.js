import React from "react";
import "./content-extra.css";
import "./styles.css";
import "./cw3e-twentysixteen.css";
import Container from "react-bootstrap/Container";

export default function CW3EFooter() {
  return (
    <Container
      fluid
      className="px-5 flex-shrink-0 mt-auto"
      style={{ maxWidth: "1320px", margin: "0 auto" }}
    >
      <CW3EFooterRaw />
    </Container>
  );
}

function CW3EFooterRaw() {
  return (
    <footer
      id="colophon"
      role="contentinfo"
      style={{ backgroundColor: "#1e6b8b" }}
    >
      <div className="footer-flex">
        <div className="footer-left">
          <div className="footer-logo-col">
            <a href="https://cw3e.ucsd.edu/">
              <img
                className="footer-logo"
                src="https://cw3e.ucsd.edu/images/cw3e_logo_files/wetransfer-b4ff74/CW3E%20Final%20Logo%20Suite/5-Vertical-Acronym%20Onlhy/Digital/PNG/CW3E-Logo-Vertical-Acronym-White.png"
                alt="CW3E Homepage"
              />
            </a>
          </div>

          <div className="footer-contact">
            <p className="footer-title">
              <b>F. Martin Ralph, PhD., Director</b>
            </p>
            <p className="footer-text">
              <b>Center For Western Weather and Water Extremes (CW3E)</b>
              <br />
              Scripps Institution of Oceanography
              <br />
              University of California, San Diego
              <br />
              9500 Gilman Drive
              <br />
              La Jolla, CA 92093
            </p>
            <p className="footer-text footer-directions">
              <a className="footer-link" href="https://cw3e.ucsd.edu/cw3e_location/">
                Directions
              </a>
            </p>
          </div>
        </div>

        <div className="footer-search-col">
          <h2 className="footer-title">Search CW3E</h2>

          <form
            role="search"
            method="get"
            className="search-form"
            action="https://cw3e.ucsd.edu/"
          >
            <label htmlFor="cw3e-search" className="screen-reader-text">
              Search for:
            </label>
            <input
              id="cw3e-search"
              type="search"
              className="search-field"
              placeholder="Search …"
              defaultValue=""
              name="s"
            />
            <button type="submit" className="search-submit" aria-label="Search">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="#fff"
                strokeWidth="2"
                strokeLinecap="round"
                aria-hidden="true"
              >
                <circle cx="11" cy="11" r="7" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </button>
          </form>

          <div className="footer-meta">
            <a className="footer-link" href="https://cw3e.ucsd.edu/disclaimer/">
              Disclaimer
            </a>
            <a className="footer-link" href="mailto:cw3e-website-g@ucsd.edu">
              Contact Webmaster
            </a>
          </div>

          <p className="footer-social">
            <a
              href="https://twitter.com/CW3E_Scripps"
              target="_blank"
              rel="noreferrer"
            >
              <img
                className="twitter_logo"
                src="https://cw3e.ucsd.edu/images/other/twitter-icon.png"
                alt=""
              />
              Follow CW3E on Twitter
            </a>
          </p>

          <div className="footer-orgs">
            <img
              src="https://cw3e.ucsd.edu/images/logos/UCSD_SIO.png"
              alt="UC San Diego, Scripps Institution of Oceanography"
            />
          </div>
        </div>
      </div>
    </footer>
  );
}
