// icons.jsx — minimal line icons used throughout the app
function Icon({ name, size = 22, stroke = 1.6, style = {} }) {
  const p = {
    width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: 'currentColor', strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round',
    style,
  };
  switch (name) {
    case 'camera': return (
      <svg {...p}><path d="M3 7h3l2-3h8l2 3h3v13H3z"/><circle cx="12" cy="13" r="4"/></svg>
    );
    case 'video': return (
      <svg {...p}><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/></svg>
    );
    case 'flash': return (
      <svg {...p}><path d="M13 2L4 14h7l-2 8 10-13h-7z"/></svg>
    );
    case 'history': return (
      <svg {...p}><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 8v5l3 2"/></svg>
    );
    case 'home': return (
      <svg {...p}><path d="M3 11l9-7 9 7v10H3z"/><path d="M10 21v-6h4v6"/></svg>
    );
    case 'settings': return (
      <svg {...p}><circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.14-1.4l2-1.55-2-3.46-2.36.94a7 7 0 0 0-2.42-1.4L13.7 2.6h-3.4l-.38 2.53a7 7 0 0 0-2.42 1.4L5.14 5.6l-2 3.46 2 1.55A7 7 0 0 0 5 12a7 7 0 0 0 .14 1.4l-2 1.55 2 3.46 2.36-.94a7 7 0 0 0 2.42 1.4l.38 2.53h3.4l.38-2.53a7 7 0 0 0 2.42-1.4l2.36.94 2-3.46-2-1.55A7 7 0 0 0 19 12z"/></svg>
    );
    case 'user': return (
      <svg {...p}><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>
    );
    case 'arrow-right': return (
      <svg {...p}><path d="M5 12h14M13 6l6 6-6 6"/></svg>
    );
    case 'arrow-left': return (
      <svg {...p}><path d="M19 12H5M11 6l-6 6 6 6"/></svg>
    );
    case 'chevron-right': return (
      <svg {...p}><path d="M9 6l6 6-6 6"/></svg>
    );
    case 'plus': return (
      <svg {...p}><path d="M12 5v14M5 12h14"/></svg>
    );
    case 'check': return (
      <svg {...p}><path d="M4 12l5 5L20 6"/></svg>
    );
    case 'x': return (
      <svg {...p}><path d="M6 6l12 12M18 6L6 18"/></svg>
    );
    case 'edit': return (
      <svg {...p}><path d="M4 20h4l11-11-4-4L4 16zM14 5l4 4"/></svg>
    );
    case 'sparkle': return (
      <svg {...p}><path d="M12 3v6M12 15v6M3 12h6M15 12h6M6 6l4 4M14 14l4 4M18 6l-4 4M10 14l-4 4"/></svg>
    );
    case 'rotate': return (
      <svg {...p}><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>
    );
    case 'help': return (
      <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .8-1 1.5V14"/><circle cx="12" cy="17.5" r="0.6" fill="currentColor"/></svg>
    );
    case 'logout': return (
      <svg {...p}><path d="M10 4H4v16h6"/><path d="M16 8l4 4-4 4M20 12H9"/></svg>
    );
    case 'apple': return (
      <svg {...p} fill="currentColor" stroke="none"><path d="M17.5 12.5c0-2.6 2-3.8 2-3.8-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.8-3.5.8-.7 0-1.9-.8-3.1-.8-1.6 0-3.1.9-3.9 2.4-1.7 2.9-.4 7.2 1.2 9.6.8 1.2 1.7 2.5 3 2.4 1.2 0 1.6-.8 3.1-.8 1.4 0 1.8.8 3.1.8 1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.7-1-2.7-3.8zM15.3 5.3c.7-.8 1.1-1.9 1-3-.9 0-2.1.6-2.7 1.4-.6.7-1.2 1.8-1 2.9 1 .1 2 -.5 2.7-1.3z"/></svg>
    );
    case 'google': return (
      <svg {...p} stroke="none" fill="none"><path d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4c-.2 1.2-.9 2.3-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z" fill="#4285F4"/><path d="M12 22c2.7 0 5-.9 6.6-2.4l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.7-5.6-4.1H3.1v2.6C4.7 19.7 8.1 22 12 22z" fill="#34A853"/><path d="M6.4 14c-.2-.6-.3-1.3-.3-2s.1-1.4.3-2V7.4H3.1C2.4 8.8 2 10.4 2 12s.4 3.2 1.1 4.6l3.3-2.6z" fill="#FBBC05"/><path d="M12 5.9c1.5 0 2.8.5 3.8 1.5l2.8-2.8C16.9 3 14.7 2 12 2 8.1 2 4.7 4.3 3.1 7.4l3.3 2.6C7.2 7.6 9.4 5.9 12 5.9z" fill="#EA4335"/></svg>
    );
    case 'mail': return (
      <svg {...p}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></svg>
    );
    case 'eye': return (
      <svg {...p}><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>
    );
    case 'eye-off': return (
      <svg {...p}><path d="M3 3l18 18M10.6 6.1A10 10 0 0 1 12 6c6 0 10 6 10 6a17 17 0 0 1-3.4 3.9M6.6 6.6A17 17 0 0 0 2 12s4 6 10 6a10 10 0 0 0 3.6-.7"/><path d="M9.9 9.9a3 3 0 1 0 4.2 4.2"/></svg>
    );
    case 'grid': return (
      <svg {...p}><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>
    );
    case 'list': return (
      <svg {...p}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>
    );
    case 'trophy': return (
      <svg {...p}><path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M16 5h3v2a3 3 0 0 1-3 3M8 5H5v2a3 3 0 0 0 3 3"/><path d="M12 13v3M9 20h6M10 16h4l1 4H9z"/></svg>
    );
    case 'globe': return (
      <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>
    );
    case 'bell': return (
      <svg {...p}><path d="M6 9a6 6 0 1 1 12 0c0 6 2 7 2 7H4s2-1 2-7zM10 20a2 2 0 0 0 4 0"/></svg>
    );
    case 'lock': return (
      <svg {...p}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
    );
    case 'gallery': return (
      <svg {...p}><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="9" r="1.5"/><path d="M3 18l5-5 4 4 3-3 6 6"/></svg>
    );
    case 'sun': return (
      <svg {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5"/></svg>
    );
    default: return null;
  }
}

Object.assign(window, { Icon });
