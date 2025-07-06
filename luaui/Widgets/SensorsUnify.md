# SensorsUnify.md
- [x] Add gameframe vbotable to allow for activation/deactivation 
    - [x] Positive means start growing from that frame
    - [x] Negative means start shrinking from that frame
- [ ] In jammer and radar and sonar, scan for active state and modify gameframe flag
- [ ] add stippling support and circumference tags
- [ ] dont use goddamned gl.Color to set color, use the uniform! 
- [ ] Ensure all widgets support inboundsness
- [ ] Ensure sonar isnt drawn below ground
    - [ ] modulate opacity within vertex shader with a define 
- Varyings - Stencil pass
    - [x] The stencil pass does not need color at all, could be completely removed
    - [x] needs only the radius passed in its vec4's
- Varyings - outline pass
    - [x] need UV, inboundsness, circleprogress
    - [x] move inboundsness multiplication into the vertex shader alpha, then the blendedcolor does not need to be flat. 
    only expose team color when needed
    unify lobby overlay detection
    use a global variable for chobby Status




