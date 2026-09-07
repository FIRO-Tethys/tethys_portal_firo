var screenReaderText = {"expand":"expand child menu","collapse":"collapse child menu"};
document.addEventListener("DOMContentLoaded", () => {
    const masthead = document.getElementById("masthead");
    if (!masthead) return;

    const menuBtn = masthead.querySelector("#menu-toggle");
    const menuWrap = masthead.querySelector("#site-header-menu");

    // Top-level Menu toggle
    if (menuBtn && menuWrap) {
        menuBtn.setAttribute("aria-controls", "site-header-menu");
        menuBtn.setAttribute("aria-expanded", menuWrap.classList.contains("toggled-on") ? "true" : "false");

        menuBtn.addEventListener("click", (e) => {
        e.preventDefault();
        const open = menuWrap.classList.toggle("toggled-on");
        menuBtn.classList.toggle("toggled-on", open);
        menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
        });
    }

    // Submenu toggles (works for nested menus too)
    masthead.addEventListener("click", (e) => {
            const btn = e.target.closest("button.dropdown-toggle");
            if (!btn) return;

            e.preventDefault();
            e.stopPropagation();

            const li = btn.closest("li");
            if (!li) return;

            const open = li.classList.toggle("toggled-on");
            btn.classList.toggle("toggled-on", open);
            btn.setAttribute("aria-expanded", open ? "true" : "false");
    });
});