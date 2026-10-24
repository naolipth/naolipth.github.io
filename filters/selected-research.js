// Home page: steps the Selected papers row one card at a time.
document.querySelectorAll('.selected-research').forEach((section) => {
  const track = section.querySelector('.selected-research__track');
  const cards = track.children;
  if (cards.length < 2) return;
  const [prev, next] = section.querySelectorAll('.selected-research__step');
  const count = section.querySelector('.selected-research__count');
  const behavior = matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth';
  // One step is a card's width plus the gap.
  const step = () => cards[1].offsetLeft - cards[0].offsetLeft;

  // Counter and buttons follow the scroll position, whether stepped, swiped or tabbed.
  const update = () => {
    const i = Math.round(track.scrollLeft / step());
    count.textContent = `${i + 1} / ${cards.length}`;
    prev.disabled = i === 0;
    next.disabled = i === cards.length - 1;
  };

  prev.addEventListener('click', () => track.scrollBy({left: -step(), behavior}));
  next.addEventListener('click', () => track.scrollBy({left: step(), behavior}));
  track.addEventListener('scroll', update, {passive: true});

  // Controls appear, and the scrollbar hides, only once this has run.
  section.classList.add('is-enhanced');
  section.querySelector('.selected-research__controls').hidden = false;
  update();
});
