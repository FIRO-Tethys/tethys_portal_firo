import React from "react";
import "./content-extra.css";
import "./styles.css";
import "./cw3e-twentysixteen.css";
import Container from "react-bootstrap/Container";

export default function CW3EFooter() {
  return (
    <Container fluid className="px-5 flex-shrink-0 mt-auto">
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
      <table
        width="100%"
        style={{
          paddingTop: 0,
          paddingLeft: 20,
          paddingRight: 20,
          paddingBottom: 0,
          border: 0,
          marginBottom: 0,
        }}
      >
        <tbody>
          <tr>
            <td
              width="6%"
              valign="top"
              align="center"
              style={{
                border: 0,
                paddingTop: 25,
                paddingBottom: 0,
                marginBottom: 0,
              }}
            >
              <center>
                <a href="https://cw3e.ucsd.edu/">
                  <img
                    src="https://cw3e.ucsd.edu/images/cw3e_logo_files/wetransfer-b4ff74/CW3E%20Final%20Logo%20Suite/5-Vertical-Acronym%20Onlhy/Digital/PNG/CW3E-Logo-Vertical-Acronym-White.png"
                    className="w-50"
                    alt="CW3E Logo"
                  />
                </a>
              </center>
            </td>

            <td
              width="33%"
              valign="top"
              style={{
                border: 0,
                paddingTop: 20,
                paddingBottom: 0,
                marginBottom: 0,
              }}
            >
              <p id="footer_titles">
                <b>F. Martin Ralph, PhD., Director</b>
              </p>
              <p className="nowrap" id="footer_text">
                <b>Center For Western Weather and Water Extremes (CW3E)</b>
                <br />
                Scripps Institution of Oceanography
                <br />
                University of California, San Diego
                <br />
                9500 Gilman Drive
                <br />
                La Jolla, CA 92093
                <br />
                <a
                  href="https://cw3e.ucsd.edu/cw3e_location/"
                  style={{ color: "#000" }}
                >
                  Directions
                </a>
              </p>
              <br />
            </td>

            <td
              width="24%"
              valign="top"
              style={{
                border: 0,
                paddingTop: 20,
                paddingBottom: 0,
                marginBottom: 0,
              }}
            >
              <p id="footer_titles">
                <b>CW3E Partners</b>
              </p>
              <p className="nowrap" id="footer_text">
                <a
                  href="http://www.water.ca.gov/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  California Department of Water Resources
                </a>
                <br />
                <a
                  href="http://www.noaa.gov/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  NOAA National Weather Service
                </a>
                <br />
                <a
                  href="https://www.jpl.nasa.gov/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  NASA/Jet Propulsion Laboratory
                </a>
                <br />
                <a
                  href="http://www.ocwd.com"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  Orange County Water District
                </a>
                <br />
                <a
                  href="http://www.scwa.ca.gov/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  Sonoma Water
                </a>
                <br />
                <a
                  href="http://www.usace.army.mil/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  U.S. Army Corps of Engineers
                </a>
                <br />
                <a
                  href="https://www.usbr.gov/"
                  style={{ color: "#fff" }}
                  target="_blank"
                  rel="noreferrer"
                >
                  U.S. Bureau of Reclamation
                </a>
              </p>
              <br />
            </td>

            <td
              width="23%"
              valign="top"
              style={{
                border: 0,
                paddingRight: 20,
                paddingTop: 20,
                paddingBottom: 0,
              }}
            >
              <p id="footer_titles">
                <b>Search CW3E</b>
              </p>

              <form
                role="search"
                method="get"
                className="search-form"
                action="https://cw3e.ucsd.edu/"
              >
                <label className="w-100">
                  <span className="screen-reader-text">Search for:</span>
                  <input
                    type="search"
                    className="search-field"
                    placeholder="Search …"
                    defaultValue=""
                    name="s"
                  />
                </label>
                <button type="submit" className="search-submit">
                  <span className="screen-reader-text">Search</span>
                </button>
              </form>

              <table style={{ paddingBottom: 0, border: 0 }}>
                <tbody>
                  <tr>
                    <td style={{ border: 0, paddingBottom: 0 }}>
                      <p className="nowrap" id="footer_text" align="left">
                        <a
                          href="https://cw3e.ucsd.edu/disclaimer/"
                          style={{ color: "#fff" }}
                        >
                          Disclaimer
                        </a>
                      </p>
                    </td>
                    <td style={{ border: 0, paddingBottom: 0, marginBottom: 0 }}>
                      <p className="nowrap" id="footer_text" align="right">
                        <a
                          href="mailto:cw3e-website-g@ucsd.edu"
                          style={{ color: "#fff" }}
                        >
                          Contact Webmaster
                        </a>
                      </p>
                    </td>
                  </tr>

                  <tr>
                    <td colSpan={2} style={{ border: 0, paddingBottom: 0 }}>
                      <a
                        href="https://twitter.com/CW3E_Scripps"
                        style={{ color: "#fff" }}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <img
                          id="twitter_logo"
                          className="twitter_logo"
                          src="https://cw3e.ucsd.edu/images/other/twitter-icon.png"
                          align="left"
                          alt="Twitter"
                        />
                      </a>

                      <p
                        className="nowrap"
                        id="footer_titles"
                        align="left"
                        style={{ paddingTop: 15 }}
                      >
                        <a
                          href="https://twitter.com/CW3E_Scripps"
                          style={{ color: "#fff" }}
                          target="_blank"
                          rel="noreferrer"
                        >
                          Follow CW3E on Twitter
                        </a>
                      </p>
                    </td>
                  </tr>
                </tbody>
              </table>

              <center>
                <img
                  src="https://cw3e.ucsd.edu/images/logos/UCSD_SIO.png"
                  style={{ marginTop: -20, marginBottom: 10 }}
                  className="w-75"
                  alt="UCSD SIO"
                />
              </center>
            </td>
          </tr>
        </tbody>
      </table>
    </footer>
  );
}
