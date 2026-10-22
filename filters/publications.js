// Research page: opens one panel per publication at a time and copies BibTeX.
document.addEventListener('click', (event) => {
  // Abstract / Non-technical / BibTeX buttons: open the clicked panel, close its siblings.
  const toggle = event.target.closest('.publication__toggle');
  if (toggle) {
    const open = toggle.getAttribute('aria-expanded') !== 'true';
    toggle.closest('.publication').querySelectorAll('.publication__toggle').forEach((button) => {
      const expanded = open && button === toggle;
      button.setAttribute('aria-expanded', String(expanded));
      document.getElementById(button.getAttribute('aria-controls')).hidden = !expanded;
    });
    return;
  }
  // Copy button: copy the BibTeX in the <pre> right after it.
  const copy = event.target.closest('.publication__copy');
  if (copy) {
    navigator.clipboard.writeText(copy.nextElementSibling.textContent).then(() => {
      copy.textContent = 'Copied';
      setTimeout(() => { copy.textContent = 'Copy'; }, 1500);
    });
  }
});
