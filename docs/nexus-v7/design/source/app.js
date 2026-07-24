(() => {
  'use strict';

  const STORAGE_KEY = 'yorks-materials-projects-v7-design';
  const root = document.getElementById('root');
  const portal = document.getElementById('portal');
  const $ = (selector, scope = document) => scope.querySelector(selector);
  const $$ = (selector, scope = document) => [...scope.querySelectorAll(selector)];
  const clone = (value) => JSON.parse(JSON.stringify(value));
  const uid = (prefix = 'id') => `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  const esc = (value = '') => String(value).replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
  const initials = (name = '') => name.split(/\s+/).filter(Boolean).slice(0, 2).map(part => part[0]).join('').toUpperCase();
  const formatMoney = value => `AED ${Number(value || 0).toLocaleString('en-AE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
  const formatQty = value => Number(value || 0).toLocaleString('en-AE', {maximumFractionDigits: 2});
  const nowText = () => new Date().toLocaleString('en-AE', {day:'2-digit', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit'});

  const icons = {
    menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',
    home:'<path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10M9 20v-6h6v6"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
    folder:'<path d="M3 6h6l2 2h10v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M3 10h18"/>',
    request:'<path d="M6 3h12v18H6z"/><path d="M9 7h6M9 11h6M9 15h4"/><path d="M4 6H2v12h2"/>',
    procurement:'<path d="M7 7h10l2 4H5z"/><path d="M5 11v8h14v-8M9 15h6"/><path d="M8 7V4h8v3"/>',
    order:'<path d="M4 4h16v16H4z"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    truck:'<path d="M3 6h11v10H3zM14 9h4l3 3v4h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/>',
    settings:'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21H9.6v-.1A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H3V9.6h.1A1.7 1.7 0 0 0 4.6 8.6a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-.6 1.7 1.7 0 0 0 .4-1.1V3h4v.1A1.7 1.7 0 0 0 15.4 4.6a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 9c.2.37.54.72 1 .95.28.14.63.2 1 .2h.1v4h-.1c-.37 0-.72.06-1 .2-.46.23-.8.58-1 .95Z"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',
    chevronRight:'<path d="m9 18 6-6-6-6"/>',
    chevronDown:'<path d="m6 9 6 6 6-6"/>',
    check:'<path d="m5 12 4 4L19 6"/>',
    x:'<path d="m6 6 12 12M18 6 6 18"/>',
    download:'<path d="M12 3v12M7 10l5 5 5-5"/><path d="M5 21h14"/>',
    upload:'<path d="M12 21V9M7 14l5-5 5 5"/><path d="M5 3h14"/>',
    building:'<path d="M4 21V4h10v17M14 9h6v12M7 8h2M7 12h2M7 16h2M16 13h2M16 17h2M2 21h20"/>',
    users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    paperclip:'<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.2-9.19a4 4 0 0 1 5.65 5.65l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>',
    history:'<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
    comment:'<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4Z"/>',
    grid:'<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>',
    list:'<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
    file:'<path d="M6 2h8l4 4v16H6z"/><path d="M14 2v5h5M9 13h6M9 17h6"/>',
    box:'<path d="m21 8-9 5-9-5 9-5z"/><path d="m3 8 9 5 9-5v8l-9 5-9-5zM12 13v8"/>',
    quote:'<path d="M4 4h16v16H4z"/><path d="M7 8h10M7 12h7M7 16h5"/>',
    link:'<path d="M10 13a5 5 0 0 0 7.1.1l2-2a5 5 0 0 0-7.1-7.1l-1.1 1.1"/><path d="M14 11a5 5 0 0 0-7.1-.1l-2 2A5 5 0 0 0 12 20l1.1-1.1"/>',
    alert:'<path d="M10.3 2.9 1.8 17a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 2.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
    lock:'<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    edit:'<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/>',
    copy:'<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    more:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/>',
    arrowRight:'<path d="M5 12h14M13 6l6 6-6 6"/>',
    arrowLeft:'<path d="M19 12H5M11 6l-6 6 6 6"/>',
    filter:'<path d="M4 5h16M7 12h10M10 19h4"/>',
    receipt:'<path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2Z"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    camera:'<path d="M4 7h3l2-3h6l2 3h3v13H4z"/><circle cx="12" cy="13" r="4"/>',
    activity:'<path d="M3 12h4l2-5 4 10 2-5h6"/>',
    eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    columns:'<path d="M4 4h16v16H4zM10 4v16M15 4v16"/>',
    sort:'<path d="M3 6h18M6 12h12M9 18h6"/>',
    refresh:'<path d="M20 11a8 8 0 1 0-2.3 5.7L20 14"/><path d="M20 8v6h-6"/>',
  };
  const icon = (name, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.file}</svg>`;

  const categories = [
    {id:'air', name:'Air Terminals', icon:'grid'},
    {id:'dampers', name:'Dampers & Fire Control', icon:'columns'},
    {id:'fans', name:'Fans & Equipment', icon:'activity'},
    {id:'duct', name:'Ductwork & Accessories', icon:'box'},
    {id:'pipe', name:'Piping & Drain', icon:'link'},
    {id:'controls', name:'Electrical & Controls', icon:'settings'},
    {id:'supports', name:'Supports & Insulation', icon:'building'},
    {id:'general', name:'General & Custom', icon:'plus'},
  ];

  const materialRows = [
    ['SAR-500','Supply Air Register','500 x 500 mm','SAR Series','Betec CAD / UAE','Nos',64,'A-01',210,'air'],
    ['RAR-600','Return Air Register','600 x 400 mm','RAR Series','Betec CAD / UAE','Nos',48,'A-02',235,'air'],
    ['EAR-400','Exhaust Air Register','400 x 300 mm','EAR Series','Local / UAE','Nos',20,'A-03',145,'air'],
    ['SAD-600','Supply Air Diffuser','600 x 600 mm','TMS-4W','Titus / USA','Nos',35,'A-04',390,'air'],
    ['RAD-600','Return Air Diffuser','600 x 600 mm','TMS-R','Titus / USA','Nos',28,'A-05',360,'air'],
    ['STL-1200','Sand Trap Louver','1200 x 900 mm','STL-50','Trox / Germany','Nos',8,'A-06',1100,'air'],
    ['MFD-500','Motorized Fire Damper','500 x 400 mm','MFD-120','Betec CAD / UAE','Nos',55,'B-01',520,'dampers'],
    ['MSFD-700','Motorized Smoke Fire Damper','700 x 500 mm','MSFD-240','Betec CAD / UAE','Nos',12,'B-02',890,'dampers'],
    ['MSD-600','Motorized Smoke Damper','600 x 450 mm','FSD-36','Ruskin / USA','Nos',9,'B-03',780,'dampers'],
    ['VCD-450','Volume Control Damper','450 x 300 mm','VCD-01','Local / UAE','Nos',34,'B-04',165,'dampers'],
    ['PRD-900','Pressure Relief Damper','900 x 700 mm','PRD-700','Trox / Germany','Nos',4,'B-05',1250,'dampers'],
    ['FAF-2753','Fresh Air Fan','2753 L/s','KBR-355','Systemair / Sweden','Nos',6,'C-01',4500,'fans'],
    ['SEF-4500','Smoke Extract Fan','4500 L/s','AXC 500','Soler & Palau / Spain','Nos',4,'C-02',6900,'fans'],
    ['EF-1200','Roof Mounted Extract Fan','1200 L/s','DVC 355','Systemair / Sweden','Nos',18,'C-03',1850,'fans'],
    ['PACU-25','Air Cooled Package Unit','25 TR','50TC-25','Carrier / USA','Set',6,'C-04',34000,'fans'],
    ['FCU-1200','Fan Coil Unit','1200 CFM','YFCN-1200','York / USA','Nos',14,'C-05',4200,'fans'],
    ['GI-08','GI Ductwork','0.8 mm','G90','Jindal / India','Meter',120,'D-01',92,'duct'],
    ['FRD-2H','Fire Rated Ductwork','2 Hour Rated','FR-120','Flamro / Germany','Meter',48,'D-02',330,'duct'],
    ['FLEX-250','Flexible Duct','Ø250 mm','ATCO-250','Atco / USA','Meter',80,'D-03',28,'duct'],
    ['AD-300','Access Door','300 x 300 mm','AD-300','Local / UAE','Nos',26,'D-04',75,'duct'],
    ['RPIPE-118','Refrigerant Copper Pipe','1 1/8 inch','ACR-L','Mueller / USA','Meter',210,'E-01',118,'pipe'],
    ['DPIPE-DN50','uPVC Drain Pipe','DN50','Class D','Hepworth / UAE','Meter',160,'E-02',24,'pipe'],
    ['VALVE-DN50','Isolation Valve','DN50','Series 300','Victaulic / USA','Nos',23,'E-03',280,'pipe'],
    ['BMS-01','BMS / HVAC Control Panel','System-01','CP-HVAC-01','Honeywell / USA','Set',3,'F-01',8900,'controls'],
    ['FPR-PNL','Fire Pump Room Control Panel','FPR-01','CP-FPR-01','Honeywell / USA','Set',2,'F-02',7200,'controls'],
    ['CABLE-4C4','Power & Control Cable','4C x 4 mm²','FLEX-4C4','Ducab / UAE','Meter',650,'F-03',18,'controls'],
    ['TRAY-300','Cable Tray / Trunking','300 x 50 mm','CT-300','Delta / UAE','Meter',120,'F-04',46,'controls'],
    ['SUP-M10','Duct Support & Clamp','M10','HDG-M10','Hilti / Liechtenstein','Set',180,'G-01',22,'supports'],
    ['INSUL-25','Duct Insulation','25 mm','K-Flex ST','K-Flex / Italy','Roll',38,'G-02',310,'supports'],
    ['SEAL-600','Fire Rated Sealant','600 ml','CFS-S SIL','Hilti / Liechtenstein','Box',12,'G-03',360,'supports'],
    ['FAST-M10','Nuts, Bolts & Washers','M10','HDG-M10','Local / UAE','Box',20,'H-01',95,'general'],
  ];

  const materials = materialRows.map((row, index) => ({
    id:`mat-${index+1}`,
    code:row[0], description:row[1], size:row[2], model:row[3], makeOrigin:row[4], unit:row[5], stock:row[6], store:row[7], unitCost:row[8], categoryId:row[9],
    categoryName:categories.find(c => c.id === row[9])?.name || 'General & Custom',
    allocated:index % 4 === 0 ? Math.min(6,row[6]) : index % 5 === 0 ? Math.min(3,row[6]) : 0,
    inTransit:index % 6 === 0 ? 12 : 0,
  }));

  const canonicalRow = (overrides = {}) => ({
    id:uid('row'), description:'', size:'', modelSerial:'', makeOrigin:'', qty:1, unit:'Nos', remarks:'', unitCost:0, status:'draft', source:'custom', ...overrides,
  });

  const seedState = {
    currentUserId:'eng-omar',
    users:[
      {id:'eng-omar',name:'Omar Farooq',role:'Engineer',title:'Site Engineer',canApprove:false,commercial:false},
      {id:'eng-imran',name:'Imran Khan',role:'Engineer',title:'Project Engineer',canApprove:true,commercial:false},
      {id:'proc-ali',name:'Ali Raza',role:'Procurement',title:'Procurement Engineer',canApprove:false,commercial:true},
      {id:'admin-faisal',name:'Faisal Ahmed',role:'Admin',title:'Operations Admin',canApprove:true,commercial:true},
    ],
    settings:{
      costVisibility:{Engineer:false,Procurement:true,Admin:true},
      units:['Nos','Meter','Cm','Length','Set','Pairs','Roll','Box'],
      customUnits:[],
      smartCarry:['description','size','makeOrigin','unit','remarks'],
      completionWeights:[
        {key:'design',label:'Cooling Load Design',weight:10},
        {key:'supply',label:'Material Supply',weight:50},
        {key:'installation',label:'Progress Installation',weight:30},
        {key:'commissioning',label:'Commissioning & Handover',weight:5},
        {key:'energizing',label:'Energizing Substation',weight:5},
      ],
    },
    projects:[
      {
        id:'nexus',ref:'YRA-322',name:'Nexus 4 Station',client:'TAQA',contractNo:'N-19957.2',location:'Al Dhafra Area, Abu Dhabi',consultant:'Atkins',mainContractor:'Larsen & Toubro (L&T)',subcontractors:['Yorks Air Conditioning and Refrigeration LLC-SPC'],otherContractors:['Civil Works Contractor'],startDate:'23 Jul 2026',endDate:'30 Jun 2027',status:'active',phase:'Execution',createdBy:'Omar Farooq',createdAt:'23 Jul 2026, 10:14',assignedEngineer:'Imran Khan',approver:'Imran Khan',procurementOwner:'Ali Raza',
        buildings:[
          {id:'df3w',code:'DF3W',name:'132/33kV Substation DF3W',floors:'Basement, GF, 1F, Roof',hasFRP:true,progress:43},
          {id:'df4w',code:'DF4W',name:'132/33kV Substation DF4W',floors:'GF, 1F, Roof',hasFRP:false,progress:34},
          {id:'df6w',code:'DF6W',name:'132/33kV Substation DF6W',floors:'Basement, GF, 1F, Roof',hasFRP:true,progress:29},
          {id:'df7w',code:'DF7W',name:'132/33kV Substation DF7W',floors:'GF, 1F, Roof',hasFRP:false,progress:22},
        ],
        completion:{design:100,supply:41,installation:14,commissioning:0,energizing:0},
        plan:{status:'approved',version:4,buildingId:'df3w',submittedBy:'Omar Farooq',processedBy:'Ali Raza',approvedBy:'Imran Khan',approvedAt:'23 Jul 2026, 16:22',rows:[
          canonicalRow({id:'p1',description:'Motorized Fire Damper',size:'500 x 400 mm',modelSerial:'MFD-01',makeOrigin:'Betec CAD / UAE',qty:1,unit:'Nos',remarks:'Staircase-02 (RAD)',unitCost:520,status:'approved',source:'inventory'}),
          canonicalRow({id:'p2',description:'Motorized Fire Damper',size:'500 x 500 mm',modelSerial:'MFD-02',makeOrigin:'Betec CAD / UAE',qty:1,unit:'Nos',remarks:'Staircase-02 (SAD)',unitCost:560,status:'approved',source:'inventory'}),
          canonicalRow({id:'p3',description:'Supply Air Register',size:'500 x 500 mm',modelSerial:'SAR-001',makeOrigin:'Betec CAD / UAE',qty:4,unit:'Nos',remarks:'Ground floor switchgear room',unitCost:210,status:'approved',source:'inventory'}),
          canonicalRow({id:'p4',description:'Fresh Air Fan',size:'2753 L/s',modelSerial:'FAF-01',makeOrigin:'Systemair / Sweden',qty:1,unit:'Nos',remarks:'Basement ventilation system',unitCost:4500,status:'approved',source:'supplier'}),
          canonicalRow({id:'p5',description:'GI Ductwork',size:'900 x 700 mm',modelSerial:'DUCT-01',makeOrigin:'Jindal / India',qty:28,unit:'Meter',remarks:'Main supply duct route',unitCost:92,status:'approved',source:'supplier'}),
        ]},
        activity:[
          {id:'a1',actor:'Omar Farooq',role:'Engineer',action:'Created project draft',detail:'Project identity and four buildings added.',time:'23 Jul 2026, 10:14'},
          {id:'a2',actor:'Omar Farooq',role:'Engineer',action:'Submitted Phase 1 material plan',detail:'5 lines sent to Procurement for arrangement.',time:'23 Jul 2026, 11:02'},
          {id:'a3',actor:'Ali Raza',role:'Procurement',action:'Completed procurement arrangement',detail:'3 inventory lines and 2 supplier lines confirmed.',time:'23 Jul 2026, 15:48'},
          {id:'a4',actor:'Imran Khan',role:'Engineer',action:'Approved material plan v4',detail:'Project moved to Active and execution requests opened.',time:'23 Jul 2026, 16:22'},
        ],
        documents:[
          {id:'d1',name:'N-19957.2_DF3W_HVAC_Layout_RevB.pdf',type:'Drawing',ref:'HV-DF3W-0061',revision:'B',uploadedBy:'Imran Khan',time:'23 Jul 2026'},
          {id:'d2',name:'Nexus_Equipment_Schedule_Rev04.xlsx',type:'Schedule',ref:'EQ-SCH-04',revision:'04',uploadedBy:'Omar Farooq',time:'23 Jul 2026'},
          {id:'d3',name:'Material_Submittal_MFD_MSFD.pdf',type:'Submittal',ref:'MASS-018',revision:'02',uploadedBy:'Ali Raza',time:'24 Jul 2026'},
        ],
      },
      {
        id:'madinat',ref:'YRA-328',name:'Madinat Zayed Workshop',client:'Abu Dhabi Projects',contractNo:'N-20214.1',location:'Madinat Zayed, Abu Dhabi',consultant:'AECOM',mainContractor:'Al Geemi',subcontractors:[],otherContractors:[],startDate:'01 Aug 2026',endDate:'15 Feb 2027',status:'procurement_review',phase:'Planning',createdBy:'Omar Farooq',createdAt:'20 Jul 2026, 09:30',assignedEngineer:'Omar Farooq',approver:'Imran Khan',procurementOwner:'Ali Raza',
        buildings:[{id:'ws01',code:'WS-01',name:'Main Workshop',floors:'Ground Floor',hasFRP:false,progress:16}],
        completion:{design:55,supply:0,installation:0,commissioning:0,energizing:0},
        plan:{status:'procurement_review',version:2,buildingId:'ws01',submittedBy:'Omar Farooq',processedBy:'Ali Raza',approvedBy:'',approvedAt:'',rows:[
          canonicalRow({id:'m1',description:'Roof Mounted Extract Fan',size:'1200 L/s',modelSerial:'EF-01',makeOrigin:'Systemair / Sweden',qty:3,unit:'Nos',remarks:'Workshop roof exhaust',unitCost:1850,status:'arranged',source:'supplier'}),
          canonicalRow({id:'m2',description:'Supply Air Register',size:'600 x 400 mm',modelSerial:'SAR-01',makeOrigin:'Betec CAD / UAE',qty:8,unit:'Nos',remarks:'Workshop supply air',unitCost:235,status:'in_stock',source:'inventory'}),
          canonicalRow({id:'m3',description:'GI Ductwork',size:'600 x 400 mm',modelSerial:'DUCT-01',makeOrigin:'Jindal / India',qty:42,unit:'Meter',remarks:'Main distribution',unitCost:78,status:'needs_info',source:'supplier'}),
        ]},
        activity:[
          {id:'ma1',actor:'Omar Farooq',role:'Engineer',action:'Created project draft',detail:'Workshop project created with one building.',time:'20 Jul 2026, 09:30'},
          {id:'ma2',actor:'Omar Farooq',role:'Engineer',action:'Submitted Phase 1 material plan',detail:'3 lines sent to Procurement.',time:'20 Jul 2026, 11:20'},
          {id:'ma3',actor:'Ali Raza',role:'Procurement',action:'Requested clarification',detail:'Please confirm duct gauge and approved drawing reference.',time:'20 Jul 2026, 14:16'},
        ],
        documents:[],
      },
    ],
    requests:[
      {
        id:'MR-2026-024',projectId:'nexus',projectName:'Nexus 4 Station',buildingId:'df3w',buildingCode:'DF3W',requestedBy:'Omar Farooq',requestedAt:'24 Jul 2026, 09:18',requiredDate:'27 Jul 2026',priority:'Urgent',status:'sourcing',currentOwner:'Ali Raza',notes:'Required before ceiling closure in the ground-floor switchgear area.',
        rows:[
          canonicalRow({id:'r1',description:'Supply Air Register',size:'500 x 500 mm',modelSerial:'SAR-011',makeOrigin:'Betec CAD / UAE',qty:6,unit:'Nos',remarks:'Ground floor relay room',unitCost:210,status:'allocated',source:'inventory'}),
          canonicalRow({id:'r2',description:'Motorized Fire Damper',size:'500 x 400 mm',modelSerial:'MFD-09',makeOrigin:'Betec CAD / UAE',qty:2,unit:'Nos',remarks:'Fire wall penetration',unitCost:520,status:'rfq',source:'supplier'}),
          canonicalRow({id:'r3',description:'Access Door',size:'300 x 300 mm',modelSerial:'AD-DF3W-07',makeOrigin:'Local / UAE',qty:4,unit:'Nos',remarks:'Ground floor duct access',unitCost:75,status:'allocated',source:'inventory'}),
          canonicalRow({id:'r4',description:'Fire Rated Sealant',size:'600 ml',modelSerial:'CFS-S SIL',makeOrigin:'Hilti / Liechtenstein',qty:2,unit:'Box',remarks:'Wall penetration sealing',unitCost:360,status:'rfq',source:'supplier'}),
        ],
        fulfilment:{
          r1:{requested:6,warehouse:6,external:0,ordered:6,received:6},
          r2:{requested:2,warehouse:0,external:2,ordered:2,received:1},
          r3:{requested:4,warehouse:4,external:0,ordered:4,received:4},
          r4:{requested:2,warehouse:0,external:2,ordered:2,received:0},
        },
        linked:{rfqs:['RFQ-2026-048'],pos:['PO-2026-1074','PO-2026-1075'],receipts:['DR-2026-041']},
        comments:[
          {actor:'Ali Raza',role:'Procurement',time:'24 Jul 2026, 09:46',text:'Warehouse stock is allocated for SAR and access doors. RFQ issued for MFD and fire-rated sealant.'},
          {actor:'Omar Farooq',role:'Engineer',time:'24 Jul 2026, 10:02',text:'Please prioritise the MFDs. One can be delivered first if the supplier cannot complete both together.'},
        ],
        activity:[
          {actor:'Omar Farooq',action:'Submitted material request',detail:'4 lines · Urgent · DF3W',time:'24 Jul 2026, 09:18'},
          {actor:'Ali Raza',action:'Reviewed and split sourcing',detail:'2 warehouse lines · 2 supplier lines',time:'24 Jul 2026, 09:46'},
          {actor:'Ali Raza',action:'Created RFQ-2026-048',detail:'Sent to 3 approved suppliers',time:'24 Jul 2026, 10:11'},
          {actor:'Ali Raza',action:'Created two purchase orders',detail:'PO-1074 and PO-1075 linked to this request',time:'24 Jul 2026, 14:40'},
        ],
      },
      {
        id:'MR-2026-021',projectId:'nexus',projectName:'Nexus 4 Station',buildingId:'df6w',buildingCode:'DF6W',requestedBy:'Imran Khan',requestedAt:'23 Jul 2026, 11:03',requiredDate:'25 Jul 2026',priority:'Normal',status:'received',currentOwner:'Completed',notes:'Basement ductwork accessories.',rows:[
          canonicalRow({id:'rr1',description:'Flexible Duct',size:'Ø250 mm',modelSerial:'ATCO-250',makeOrigin:'Atco / USA',qty:20,unit:'Meter',remarks:'Basement branch connections',unitCost:28,status:'received',source:'inventory'}),
        ],fulfilment:{rr1:{requested:20,warehouse:20,external:0,ordered:20,received:20}},linked:{rfqs:[],pos:[],receipts:['DR-2026-037']},comments:[],activity:[]
      },
    ],
    rfq:{id:'RFQ-2026-048',requestId:'MR-2026-024',status:'quotes_received',suppliers:[
      {id:'sup-gulf',name:'Gulf Air Controls LLC',leadDays:3,validity:'14 days',quoteRef:'Q-4421',currency:'AED'},
      {id:'sup-mep',name:'MEP Source Trading',leadDays:5,validity:'21 days',quoteRef:'MS-8893',currency:'AED'},
      {id:'sup-emirates',name:'Emirates Duct Solutions',leadDays:2,validity:'14 days',quoteRef:'EDS-1077',currency:'AED'},
    ],prices:{
      r2:{'sup-gulf':535,'sup-mep':510,'sup-emirates':548},
      r4:{'sup-gulf':370,'sup-mep':355,'sup-emirates':362},
    },selected:{r2:'sup-mep',r4:'sup-emirates'}},
    purchaseOrders:[
      {id:'PO-2026-1074',requestId:'MR-2026-024',supplier:'MEP Source Trading',status:'Partially received',createdBy:'Ali Raza',createdAt:'24 Jul 2026, 14:32',requiredDate:'27 Jul 2026',revision:2,items:[
        {rowId:'r2',description:'Motorized Fire Damper',size:'500 x 400 mm',modelSerial:'MFD-09',ordered:2,received:1,unit:'Nos',unitCost:510},
      ],documents:[{name:'PO-2026-1074-Rev02.pdf',type:'Purchase Order',uploadedBy:'Ali Raza',time:'24 Jul 2026'},{name:'Delivery_Note_DN-8421.jpg',type:'Delivery Note',uploadedBy:'Omar Farooq',time:'26 Jul 2026'}],history:[
        {actor:'Ali Raza',action:'Created PO revision 1',detail:'2 MFDs at AED 525 each',time:'24 Jul 2026, 14:32'},
        {actor:'Ali Raza',action:'Issued PO revision 2',detail:'Rate revised to AED 510 after supplier confirmation',time:'24 Jul 2026, 15:08'},
        {actor:'Omar Farooq',action:'Recorded partial receipt',detail:'1 of 2 MFDs received in good condition',time:'26 Jul 2026, 09:40'},
      ]},
      {id:'PO-2026-1075',requestId:'MR-2026-024',supplier:'Emirates Duct Solutions',status:'In transit',createdBy:'Ali Raza',createdAt:'24 Jul 2026, 14:40',requiredDate:'27 Jul 2026',revision:1,items:[
        {rowId:'r4',description:'Fire Rated Sealant',size:'600 ml',modelSerial:'CFS-S SIL',ordered:2,received:0,unit:'Box',unitCost:362},
      ],documents:[{name:'PO-2026-1075.pdf',type:'Purchase Order',uploadedBy:'Ali Raza',time:'24 Jul 2026'}],history:[{actor:'Ali Raza',action:'Created and issued PO',detail:'2 boxes · Supplier delivery confirmed',time:'24 Jul 2026, 14:40'}]},
    ],
    ui:{
      browseCategory:'all',browseSearch:'',browseSelectedId:'mat-1',
      projectId:'nexus',projectTab:'overview',
      selectedPlanRowId:'p1',selectedRequestId:'MR-2026-024',procurementTab:'fulfilment',
      pickerTarget:null,pickerSelected:[],pickerCategory:'all',pickerSearch:'',
      wizardStep:1,wizardDraft:null,sizeTarget:null,sizeMode:'rectangular',
      commandOpen:false,
      newRequest:{projectId:'nexus',buildingId:'df3w',priority:'Normal',requiredDate:'',notes:'',rows:[canonicalRow({id:'nr1',description:'Supply Air Register',size:'500 x 500 mm',modelSerial:'SAR-021',makeOrigin:'Betec CAD / UAE',qty:2,unit:'Nos',remarks:'First-floor relay room',unitCost:210,source:'inventory'})]},
    },
  };

  let state;
  function loadState(){
    try{ state = JSON.parse(localStorage.getItem(STORAGE_KEY)) || clone(seedState); }
    catch{ state = clone(seedState); }
    state.settings ||= clone(seedState.settings);
    state.ui ||= clone(seedState.ui);
    state.ui.newRequest ||= clone(seedState.ui.newRequest);
    if(!state.users.some(user => user.id === state.currentUserId)) state.currentUserId = 'eng-omar';
  }
  function saveState(){
    try{ localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }catch{}
    const el = document.querySelector('[data-sync-state]');
    if(el) el.innerHTML = '<i></i> Saved';
  }
  function resetState(){
    localStorage.removeItem(STORAGE_KEY);
    state = clone(seedState);
    toast('Demo restored','The original client-review data has been restored.','check');
    render();
  }
  const currentUser = () => state.users.find(user => user.id === state.currentUserId) || state.users[0];
  const canSeeCosts = () => !!state.settings.costVisibility[currentUser().role] && !!currentUser().commercial;
  const allUnits = () => [...state.settings.units, ...state.settings.customUnits];
  const projectById = id => state.projects.find(project => project.id === id);
  const requestById = id => state.requests.find(request => request.id === id);
  const poById = id => state.purchaseOrders.find(po => po.id === id);
  const completion = project => Math.round(state.settings.completionWeights.reduce((sum, stage) => sum + (Number(project.completion[stage.key] || 0) * stage.weight / 100), 0));
  const route = () => (location.hash || '#project/nexus/overview').replace(/^#/,'').split('/').filter(Boolean);
  const go = path => { location.hash = path.startsWith('#') ? path : `#${path}`; };

  const projectStatus = status => ({draft:['Draft','neutral'],submitted:['Submitted','blue'],procurement_review:['Procurement review','amber'],ready_for_approval:['Engineer approval','purple'],active:['Active','green'],on_hold:['On hold','red'],completed:['Completed','green']}[status] || [status,'neutral']);
  const requestStatus = status => ({draft:['Draft','neutral'],submitted:['Submitted','blue'],reviewed:['Reviewed','blue'],sourcing:['Sourcing','amber'],ordered:['Ordered','purple'],partial:['Partially received','amber'],received:['Received','green'],closed:['Closed','green'],on_hold:['On hold','red'],cancelled:['Cancelled','red']}[status] || [status,'neutral']);
  const rowStatus = status => ({draft:['Draft','gray'],pending:['Pending','gray'],in_stock:['In stock','green'],arranged:['Arranged','blue'],needs_info:['Needs info','amber'],approved:['Approved','green'],allocated:['Allocated','green'],rfq:['RFQ','blue'],ordered:['Ordered','purple'],received:['Received','green']}[status] || [status,'gray']);

  function chip(label,type='neutral',dot=''){
    return `<span class="chip ${type}">${dot?`<i class="status-dot ${dot}"></i>`:''}${esc(label)}</span>`;
  }
  function toast(title,message,iconName='check'){
    let stack = document.querySelector('.toast-stack');
    if(!stack){ stack = document.createElement('div'); stack.className='toast-stack'; document.body.appendChild(stack); }
    const item = document.createElement('div');
    item.className='toast';
    item.innerHTML=`<div class="toast-icon">${icon(iconName)}</div><div><strong>${esc(title)}</strong><span>${esc(message)}</span></div>`;
    stack.appendChild(item);
    setTimeout(()=>item.remove(),3800);
  }
  function pageHeader(eyebrow,title,description,actions=''){
    return `<div class="page-head"><div class="page-title"><span class="eyebrow">${esc(eyebrow)}</span><h1>${esc(title)}</h1><p>${esc(description)}</p></div><div class="page-actions">${actions}</div></div>`;
  }
  function sidebar(active){
    const user = currentUser();
    const pending = state.projects.filter(p=>['submitted','procurement_review','ready_for_approval'].includes(p.status)).length + state.requests.filter(r=>['submitted','sourcing','ordered','partial'].includes(r.status)).length;
    const nav = [
      ['home','Home','home'],['browse','Browse Materials','search'],['projects','Projects','folder'],['requests','Material Requests','request']
    ];
    if(user.role==='Procurement'||user.role==='Admin') nav.push(['procurement','Procurement','procurement'],['orders','Purchase Orders','order'],['deliveries','Deliveries','truck']);
    return `<aside class="sidebar" id="sidebar">
      <div class="brand"><img src="assets/yorks-logo.png" alt="Yorks logo"><div class="brand-copy"><strong>Yorks Materials & Projects</strong><span>Yorks Air Conditioning and Refrigeration LLC-SPC</span></div></div>
      <div class="nav-section"><div class="nav-label">Workspace</div>${nav.map(([path,label,ic])=>`<button class="nav-item ${active===path?'active':''}" data-route="${path}">${icon(ic)}<span>${label}</span>${path==='procurement'&&pending?`<span class="nav-badge">${pending}</span>`:''}</button>`).join('')}</div>
      <div class="sidebar-spacer"></div>
      <div class="sidebar-foot"><div class="version"><i class="dot"></i> Client design v7</div><div>Connected project, request, sourcing, order and receipt experience.</div><button class="btn ghost sm" data-action="reset" style="margin-top:8px;padding-left:0">Reset demo data</button></div>
    </aside>`;
  }
  function topbar(crumbs=[]){
    const user=currentUser();
    const userLabel=`${user.name} — ${user.role}`;
    return `<header class="topbar">
      <div class="top-left"><button class="menu-btn" data-action="toggle-sidebar">${icon('menu')}</button><div class="crumbs"><span>Yorks</span>${crumbs.map((c,i)=>`${i===0?'<span class="crumb-sep">/</span>':''}<b>${esc(c)}</b>`).join('<span class="crumb-sep">/</span>')}</div></div>
      <div class="top-right">
        <button class="command" data-action="command">${icon('search')}<span>Search or jump to…</span><kbd>⌘K</kbd></button>
        <div class="sync-state" data-sync-state><i></i> Saved</div>
        ${currentUser().role==='Admin'?`<button class="btn sm soft" data-action="cost-settings">${icon('lock')} Cost access</button>`:`<span class="chip ${canSeeCosts()?'green':'neutral'}">${canSeeCosts()?'Commercial access':'Costs protected'}</span>`}
        <select class="role-select" data-action="switch-user" aria-label="View prototype as another user">${state.users.map(u=>`<option value="${u.id}" ${u.id===user.id?'selected':''}>${esc(u.name)} — ${esc(u.role)}</option>`).join('')}</select>
        <button class="avatar" title="${esc(userLabel)}">${esc(initials(user.name))}</button>
      </div>
    </header>`;
  }
  function mobileNav(active){
    const nav=[['home','Home','home'],['browse','Browse','search'],['projects','Projects','folder'],['requests','Requests','request']];
    return `<nav class="mobile-nav">${nav.map(([path,label,ic])=>`<button data-route="${path}" class="${active===path?'active':''}">${icon(ic)}<span>${label}</span></button>`).join('')}</nav>`;
  }
  function shell(content,active,crumbs=[]){
    return `<div class="app-shell">${sidebar(active)}<main class="app-main">${topbar(crumbs)}${content}</main>${mobileNav(active)}</div>`;
  }
  function projectTabs(project,active){
    const user=currentUser();
    const tabs=[['overview','Overview'],['plan','Material Plan'],['requests','Requests'],['documents','Documents'],['activity','Activity']];
    if(user.role==='Procurement'||user.role==='Admin') tabs.splice(3,0,['procurement','Procurement']);
    return `<div class="project-tabs">${tabs.map(([id,label])=>`<button class="project-tab ${active===id?'active':''}" data-route="project/${project.id}/${id}">${esc(label)}</button>`).join('')}</div>`;
  }
  function projectHero(project,active,actions=''){
    const [status,type]=projectStatus(project.status);
    return `<div class="project-hero"><div class="project-hero-top"><div class="project-identity"><div class="project-mark">${esc(project.ref.split('-').pop())}</div><div><span class="eyebrow">Project workspace</span><h1>${esc(project.name)}</h1><div class="project-meta"><span>${esc(project.ref)}</span><span>•</span><span>${esc(project.contractNo)}</span><span>•</span><span>${esc(project.client)}</span>${chip(status,type)}</div></div></div><div class="page-actions">${actions}</div></div>${projectTabs(project,active)}</div>`;
  }
  function lifecycle(stage='active'){
    const steps=[['draft','Draft created','Omar Farooq'],['submitted','Plan submitted','Omar Farooq'],['procurement','Procurement arranged','Ali Raza'],['approval','Engineer approved','Imran Khan'],['active','Active project','Execution open']];
    const order={draft:0,submitted:1,procurement_review:2,ready_for_approval:3,active:4,on_hold:4,completed:4};
    const index=order[stage]??4;
    return `<div class="card flat"><div class="lifecycle">${steps.map((step,i)=>`<div class="life-step ${i<index?'done':i===index?'current':''}"><div class="life-num">${i<index?icon('check'):i+1}</div><div class="life-copy"><strong>${esc(step[1])}</strong><span>${esc(step[2])}</span></div></div>`).join('')}</div></div>`;
  }
  function recordChain(request){
    const nodes=[['Material Request',request.id,'request/'+request.id],['RFQ',request.linked.rfqs[0]||'Not created','procurement/'+request.id],['Purchase Orders',request.linked.pos.length?request.linked.pos.join(', '):'Not created',request.linked.pos[0]?'po/'+request.linked.pos[0]:'procurement/'+request.id],['Delivery Receipts',request.linked.receipts[0]||'Awaiting delivery',request.linked.pos[0]?'po/'+request.linked.pos[0]:'request/'+request.id]];
    return `<div class="link-chain">${nodes.map((node,i)=>`${i?'<span class="link-arrow">→</span>':''}<div class="link-node" data-route="${node[2]}"><span>${esc(node[0])}</span><strong>${esc(node[1])}</strong></div>`).join('')}</div>`;
  }
  function activityList(items=[]){
    if(!items.length) return `<div class="empty-state"><div class="empty-icon">${icon('history')}</div><h3>No activity yet</h3><p>Every important change will appear here with the actor and exact time.</p></div>`;
    return `<div class="activity-list">${items.map(item=>`<div class="activity-item"><div class="activity-icon">${icon('activity')}</div><div class="activity-copy"><strong>${esc(item.actor||item.who||'System')} · ${esc(item.action)}</strong><p>${esc(item.detail||'')}</p><time>${esc(item.time||'')}</time></div></div>`).join('')}</div>`;
  }
  function comments(items=[]){
    if(!items.length) return `<div class="empty-state" style="padding:20px 10px"><div class="empty-icon">${icon('comment')}</div><h3>No comments</h3><p>Keep technical questions and decisions attached to this record.</p></div>`;
    return `<div class="comments">${items.map(item=>`<div class="comment"><div class="comment-avatar">${esc(initials(item.actor||item.author))}</div><div class="comment-body"><div class="meta"><strong>${esc(item.actor||item.author)}</strong><span>${esc(item.role||'')}</span><span>· ${esc(item.time)}</span></div><p>${esc(item.text)}</p></div></div>`).join('')}</div>`;
  }

  function homePage(){
    const user=currentUser();
    const isOffice=user.role==='Procurement'||user.role==='Admin';
    const nexus=projectById('nexus');
    const pendingPlans=state.projects.filter(p=>['submitted','procurement_review','ready_for_approval'].includes(p.status)).length;
    const openRequests=state.requests.filter(r=>!['received','closed','cancelled'].includes(r.status)).length;
    const actions=isOffice?[
      {title:'Review Madinat Zayed material plan',detail:'3 lines · 1 clarification open · Ali Raza owns the next action',route:'project/madinat/plan',tone:'amber'},
      {title:'Continue sourcing MR-2026-024',detail:'2 supplier lines · 1 partial receipt · required 27 Jul',route:'procurement/MR-2026-024',tone:'blue'},
      {title:'Record remaining MFD delivery',detail:'PO-2026-1074 · 1 of 2 received',route:'po/PO-2026-1074',tone:'green'},
    ]:[
      {title:'Track urgent request MR-2026-024',detail:'Supplier sourcing in progress · 3 of 4 lines fulfilled',route:'request/MR-2026-024',tone:'blue'},
      {title:'Review project completeness',detail:'Nexus is 36% complete · material supply is the current constraint',route:'project/nexus/overview',tone:'green'},
      {title:'Create a site material request',detail:'Select a project, add materials, and submit in three steps',route:'requests/new',tone:'amber'},
    ];
    const content=`<section class="page">
      ${pageHeader('Calm operational workspace',`Good ${new Date().getHours()<12?'morning':'afternoon'}, ${user.name.split(' ')[0]}`,isOffice?'One queue for project plans, sourcing, purchase orders and deliveries. Nothing is re-entered and every record stays connected.':'See what needs attention, browse the approved material catalogue and raise a clean request without calling the office.',`<button class="btn primary" data-route="${isOffice?'procurement':'requests/new'}">${isOffice?'Open procurement desk':'New material request'} ${icon('arrowRight')}</button>`)}
      <div class="grid four metric-grid">
        <div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('folder')}</div>${chip('Live','blue')}</div><div><strong>${state.projects.length}</strong><p>Projects in workspace</p></div></div>
        <div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('activity')}</div>${chip('Needs action','amber')}</div><div><strong>${pendingPlans}</strong><p>Planning reviews</p></div></div>
        <div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('request')}</div>${chip('Open','blue')}</div><div><strong>${openRequests}</strong><p>Material requests</p></div></div>
        <div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('check')}</div>${chip('Weighted','neutral')}</div><div><strong>${completion(nexus)}%</strong><p>Nexus completeness</p></div></div>
      </div>
      <div class="split" style="margin-top:14px">
        <div class="card"><div class="section-head"><div><h2>Your action queue</h2><p>Ordered by what will unblock work fastest.</p></div><button class="btn ghost sm" data-route="${isOffice?'procurement':'requests'}">View all ${icon('arrowRight')}</button></div><div class="section-body list">${actions.map(item=>`<div class="list-row"><span class="status-dot ${item.tone}"></span><div class="grow"><strong>${esc(item.title)}</strong><span>${esc(item.detail)}</span></div><button class="btn icon-only sm ghost" data-route="${item.route}">${icon('chevronRight')}</button></div>`).join('')}</div></div>
        <div class="card"><div class="section-head"><div><h2>Connected lifecycle</h2><p>One source of truth from field need to receipt.</p></div></div><div class="section-body">${recordChain(requestById('MR-2026-024'))}<div class="notice green" style="margin-top:14px"><div class="notice-icon">${icon('link')}</div><div><strong>No duplicate entry</strong><p>The request lines flow into RFQs, purchase orders and receipts with their original project and building references intact.</p></div></div></div></div>
      </div>
      <div class="grid two" style="margin-top:14px">
        <div class="card"><div class="section-head"><div><h2>Nexus project completeness</h2><p>Weighted progress across the agreed project stages.</p></div><button class="btn sm" data-route="project/nexus/overview">Open project</button></div><div class="section-body"><div class="completion-wrap"><div class="completion-ring" style="--percent:${completion(nexus)*3.6}deg"><div class="ring-copy"><strong>${completion(nexus)}%</strong><span>overall completion</span></div></div><div class="stage-list">${state.settings.completionWeights.map(stage=>`<div class="stage-row"><div class="label">${esc(stage.label)}<small>${stage.weight}% weight</small></div><div class="pct">${nexus.completion[stage.key]}%</div><div class="progress ${nexus.completion[stage.key]===100?'green':nexus.completion[stage.key]<20?'amber':''}"><span style="width:${nexus.completion[stage.key]}%"></span></div></div>`).join('')}</div></div></div></div>
        <div class="card"><div class="section-head"><div><h2>Recent audit activity</h2><p>Who did what, when, and what changed.</p></div><button class="btn ghost sm" data-route="project/nexus/activity">Full history</button></div><div class="section-body">${activityList(nexus.activity.slice(-4).reverse())}</div></div>
      </div>
    </section>`;
    return shell(content,'home',['Home']);
  }

  function filteredMaterials(){
    const q=state.ui.browseSearch.trim().toLowerCase();
    return materials.filter(item=>(state.ui.browseCategory==='all'||item.categoryId===state.ui.browseCategory)&&(!q||[item.code,item.description,item.size,item.model,item.makeOrigin,item.categoryName].some(value=>String(value).toLowerCase().includes(q))));
  }
  function browsePage(){
    const list=filteredMaterials();
    const selected=materials.find(item=>item.id===state.ui.browseSelectedId)||list[0]||materials[0];
    const categoriesWithCounts=categories.map(cat=>({...cat,count:materials.filter(m=>m.categoryId===cat.id).length}));
    const content=`<section class="page">
      ${pageHeader('Approved material catalogue','Browse materials','A Finder-like catalogue for fast scanning. Search by description, tag, size, model or make; category filters stay familiar across project plans and site requests.',`<button class="btn" data-action="export-browse">${icon('download')} Export CSV</button><button class="btn primary" data-action="open-picker" data-target="request">${icon('plus')} Add to request</button>`)}
      <div class="finder">
        <aside class="finder-side"><div class="finder-section-title">Categories</div><button class="finder-category ${state.ui.browseCategory==='all'?'active':''}" data-browse-category="all">${icon('grid')} All materials <span class="count">${materials.length}</span></button>${categoriesWithCounts.map(cat=>`<button class="finder-category ${state.ui.browseCategory===cat.id?'active':''}" data-browse-category="${cat.id}">${icon(cat.icon)} ${esc(cat.name)} <span class="count">${cat.count}</span></button>`).join('')}</aside>
        <div class="finder-main"><div class="finder-bar"><div class="searchbox">${icon('search')}<input data-browse-search placeholder="Search description, code, size, model or make…" value="${esc(state.ui.browseSearch)}"></div><button class="btn icon-only sm" title="Filter">${icon('filter')}</button><button class="btn icon-only sm" title="Sort">${icon('sort')}</button></div><div class="finder-list"><table class="finder-table"><thead><tr><th>Material</th><th>Category</th><th>Available</th><th>Unit</th><th>Store</th></tr></thead><tbody>${list.map(item=>{const available=Math.max(0,item.stock-item.allocated);const stockType=available===0?'out':available<10?'low':'good';return `<tr class="${selected?.id===item.id?'selected':''}" data-browse-select="${item.id}"><td><div class="material-name"><div class="material-icon">${esc(item.code.split('-')[0].slice(0,3))}</div><div><strong>${esc(item.description)}</strong><small>${esc(item.code)} · ${esc(item.size)}</small></div></div></td><td>${esc(item.categoryName)}</td><td><span class="stock-text ${stockType}">${formatQty(available)} ${esc(item.unit)}</span></td><td>${esc(item.unit)}</td><td>${esc(item.store)}</td></tr>`}).join('')}</tbody></table></div><div class="table-footer"><span>Showing <b>${list.length}</b> of ${materials.length} materials</span><span>Available = on hand − allocated</span></div></div>
        <aside class="finder-preview">${selected?`<div class="preview-mark">${esc(selected.code.split('-')[0].slice(0,4))}</div><h2 class="preview-title">${esc(selected.description)}</h2><div class="preview-code">${esc(selected.code)} · ${esc(selected.categoryName)}</div><div class="preview-spec"><div class="fact-row"><span>Size</span><strong>${esc(selected.size)}</strong></div><div class="fact-row"><span>Model</span><strong>${esc(selected.model)}</strong></div><div class="fact-row"><span>Make / Origin</span><strong>${esc(selected.makeOrigin)}</strong></div><div class="fact-row"><span>On hand</span><strong>${formatQty(selected.stock)} ${esc(selected.unit)}</strong></div><div class="fact-row"><span>Allocated</span><strong>${formatQty(selected.allocated)} ${esc(selected.unit)}</strong></div><div class="fact-row"><span>In transit</span><strong>${formatQty(selected.inTransit)} ${esc(selected.unit)}</strong></div>${canSeeCosts()?`<div class="fact-row"><span>Current unit cost</span><strong>${formatMoney(selected.unitCost)}</strong></div>`:''}</div><div class="preview-actions"><button class="btn primary" data-action="quick-add-material" data-material="${selected.id}">${icon('plus')} Add to current request</button><button class="btn" data-action="open-picker" data-target="plan">${icon('folder')} Add to project plan</button></div>`:''}</aside>
      </div>
    </section>`;
    return shell(content,'browse',['Browse Materials']);
  }

  function projectsPage(){
    const content=`<section class="page">
      ${pageHeader('Project workspaces','Projects','Every project is a connected container for buildings, approved plans, site requests, procurement documents, deliveries and audit history.',`<button class="btn primary" data-route="projects/new">${icon('plus')} Create project</button>`)}
      <div class="project-list"><div class="project-row header"><div>Project</div><div>Status</div><div>Completeness</div><div>Current owner</div><div>Next action</div><div></div></div>${state.projects.map(project=>{const [label,type]=projectStatus(project.status);const next=project.status==='active'?'Execution open':project.status==='procurement_review'?'Procurement review':'Continue setup';const owner=project.status==='procurement_review'?project.procurementOwner:project.assignedEngineer;return `<div class="project-row" data-route="project/${project.id}/overview"><div class="project-main"><div class="mark">${esc(project.ref.split('-').pop())}</div><div><strong>${esc(project.name)}</strong><span>${esc(project.ref)} · ${esc(project.client)} · ${project.buildings.length} building${project.buildings.length===1?'':'s'}</span></div></div><div>${chip(label,type)}</div><div class="project-progress"><div class="progress"><span style="width:${completion(project)}%"></span></div><b>${completion(project)}%</b></div><div class="value">${esc(owner)}</div><div class="value">${esc(next)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')}</div>
      <div class="notice" style="margin-top:14px"><div class="notice-icon">${icon('link')}</div><div><strong>Project as the single source of truth</strong><p>Material plans, requests, RFQs, purchase orders, receipts, documents and activity remain related to the project rather than copied into unrelated screens.</p></div></div>
    </section>`;
    return shell(content,'projects',['Projects']);
  }

  function projectOverview(project){
    const [status,type]=projectStatus(project.status);
    const openReq=state.requests.filter(request=>request.projectId===project.id&&!['received','closed','cancelled'].includes(request.status)).length;
    const poCount=state.purchaseOrders.filter(po=>requestById(po.requestId)?.projectId===project.id).length;
    const nextAction=project.status==='active'?`Execution is open. ${openReq} material request${openReq===1?' is':'s are'} currently in progress.`:'Procurement is arranging the Phase 1 plan before Engineer approval.';
    const content=`<div class="project-shell">${projectHero(project,'overview',`<button class="btn" data-action="export-project" data-project="${project.id}">${icon('download')} Export</button><button class="btn primary" data-route="${project.status==='active'?'requests/new':`project/${project.id}/plan`}">${project.status==='active'?'New material request':'Open material plan'} ${icon('arrowRight')}</button>`)}</div><div class="project-content">
      ${lifecycle(project.status)}
      <div class="notice ${project.status==='active'?'green':''}" style="margin-top:14px"><div class="notice-icon">${icon(project.status==='active'?'check':'activity')}</div><div><strong>Current state: ${esc(status)}</strong><p>${esc(nextAction)} Current action owner: ${esc(project.status==='active'?project.assignedEngineer:project.procurementOwner)}.</p></div></div>
      <div class="project-grid" style="margin-top:14px"><div class="card"><div class="section-head"><div><h2>Project completeness</h2><p>Weighted by the Nexus project stages. Every update records the user and time.</p></div>${chip(`${completion(project)}% overall`,'blue')}</div><div class="section-body"><div class="completion-wrap"><div class="completion-ring" style="--percent:${completion(project)*3.6}deg"><div class="ring-copy"><strong>${completion(project)}%</strong><span>overall completion</span></div></div><div class="stage-list">${state.settings.completionWeights.map(stage=>`<div class="stage-row"><div class="label">${esc(stage.label)}<small>${stage.weight}% weight</small></div><div class="pct">${project.completion[stage.key]}%</div><div class="progress ${project.completion[stage.key]===100?'green':project.completion[stage.key]<20?'amber':''}"><span style="width:${project.completion[stage.key]}%"></span></div></div>`).join('')}</div></div></div></div><div class="card"><div class="section-head"><div><h2>Responsibility</h2><p>Clear ownership for every important step.</p></div></div><div class="section-body fact-list"><div class="fact-row"><span>Created by</span><strong>${esc(project.createdBy)}<br><small>${esc(project.createdAt)}</small></strong></div><div class="fact-row"><span>Assigned Engineer</span><strong>${esc(project.assignedEngineer)}</strong></div><div class="fact-row"><span>Procurement owner</span><strong>${esc(project.procurementOwner)}</strong></div><div class="fact-row"><span>Technical approver</span><strong>${esc(project.approver)}</strong></div><div class="fact-row"><span>Status</span><strong>${chip(status,type)}</strong></div></div></div></div>
      <div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Connected records</h2><p>Open related records instead of copying data between modules.</p></div></div><div class="section-body related-grid"><div class="related-card" data-route="project/${project.id}/plan"><div class="top">${icon('columns')} ${chip(project.plan.status==='approved'?'Approved':'Review','green')}</div><strong>${project.plan.rows.length}</strong><span>Material-plan lines · v${project.plan.version}</span></div><div class="related-card" data-route="project/${project.id}/requests"><div class="top">${icon('request')} ${chip(openReq?'Open':'Clear',openReq?'amber':'green')}</div><strong>${state.requests.filter(r=>r.projectId===project.id).length}</strong><span>Material requests · ${openReq} open</span></div><div class="related-card" data-route="project/${project.id}/procurement"><div class="top">${icon('order')} ${chip(poCount?'Linked':'None',poCount?'blue':'neutral')}</div><strong>${poCount}</strong><span>Purchase orders</span></div><div class="related-card" data-route="project/${project.id}/documents"><div class="top">${icon('file')} ${chip('Controlled','neutral')}</div><strong>${project.documents.length}</strong><span>Documents and revisions</span></div></div></div>
      <div class="grid two" style="margin-top:14px"><div class="card"><div class="section-head"><div><h2>Buildings</h2><p>Multiple buildings, optional floors and one FRP Yes/No decision.</p></div></div><div class="section-body" style="padding:0"><table class="building-table"><thead><tr><th>Code</th><th>Building</th><th>Floors / Levels</th><th>FRP room</th><th>Completion</th></tr></thead><tbody>${project.buildings.map(b=>`<tr><td class="building-code">${esc(b.code)}</td><td>${esc(b.name)}</td><td>${esc(b.floors||'Optional / not set')}</td><td>${chip(b.hasFRP?'Yes':'No',b.hasFRP?'blue':'neutral')}</td><td><div class="project-progress"><div class="progress"><span style="width:${b.progress}%"></span></div><b>${b.progress}%</b></div></td></tr>`).join('')}</tbody></table></div></div><div class="card"><div class="section-head"><div><h2>Recent activity</h2><p>Transparent project history.</p></div><button class="btn ghost sm" data-route="project/${project.id}/activity">View all</button></div><div class="section-body">${activityList(project.activity.slice(-4).reverse())}</div></div></div>
    </div>`;
    return shell(content,'projects',['Projects',project.name]);
  }

  function canonicalTable(rows,{scope='plan',editable=true,selectedId='',showToolbar=false,project=null}={}){
    const costs=canSeeCosts();
    const unitOptions=allUnits().map(unit=>`<option value="${esc(unit)}">${esc(unit)}</option>`).join('');
    const total=rows.reduce((sum,row)=>sum+Number(row.qty||0)*Number(row.unitCost||0),0);
    const body=rows.length?rows.map((row,index)=>{
      const [statusLabel,statusTone]=rowStatus(row.status);
      const totalCost=Number(row.qty||0)*Number(row.unitCost||0);
      const input=(field,value,type='text',attrs='')=>editable?`<input class="cell-input" type="${type}" value="${esc(value)}" data-grid-cell data-scope="${scope}" data-row="${row.id}" data-field="${field}" ${attrs}>`:`<span style="display:block;padding:12px 8px">${esc(value||'—')}</span>`;
      return `<tr class="${selectedId===row.id?'row-selected':''}" data-select-row="${row.id}" data-scope="${scope}">
        <td class="sno"><div class="row-status" title="${esc(statusLabel)}"><i class="status-dot ${statusTone}"></i><span>${index+1}</span>${editable?`<button class="row-menu" data-action="row-menu" data-scope="${scope}" data-row="${row.id}" title="Row actions">${icon('more')}</button>`:''}</div></td>
        <td style="min-width:190px">${input('description',row.description)}</td>
        <td style="min-width:130px">${editable?`<button class="size-button" data-action="size-builder" data-scope="${scope}" data-row="${row.id}">${esc(row.size||'Add size…')}</button>`:`<span style="display:block;padding:12px 8px">${esc(row.size||'—')}</span>`}</td>
        <td style="min-width:145px">${input('modelSerial',row.modelSerial)}</td>
        <td style="min-width:160px">${input('makeOrigin',row.makeOrigin)}</td>
        <td style="width:82px">${input('qty',row.qty,'number','min="0" step="1"')}</td>
        <td style="width:96px">${editable?`<select class="cell-select" data-grid-cell data-scope="${scope}" data-row="${row.id}" data-field="unit">${unitOptions.replace(`value="${esc(row.unit)}"`,`value="${esc(row.unit)}" selected`)}<option value="__custom__">+ Custom…</option></select>`:`<span style="display:block;padding:12px 8px">${esc(row.unit)}</span>`}</td>
        <td style="min-width:210px">${input('remarks',row.remarks)}</td>
        ${costs?`<td style="width:120px">${input('unitCost',row.unitCost,'number','min="0" step="0.01"')}</td><td style="width:120px"><div class="money-cell">${formatMoney(totalCost)}</div></td>`:''}
      </tr>`;
    }).join(''):`<tr><td colspan="${costs?10:8}"><div class="empty-state"><div class="empty-icon">${icon('plus')}</div><h3>No material lines yet</h3><p>${editable?'Add from the approved catalogue or create a blank row. The table keeps the same familiar columns everywhere.':'No material lines were recorded in this revision.'}</p>${editable?`<button class="btn primary" data-action="open-picker" data-target="${scope}">${icon('plus')} Add materials</button>`:''}</div></td></tr>`;
    const toolbarActions=editable?`<button class="btn sm" data-action="open-picker" data-target="${scope}">${icon('plus')} Add materials</button><button class="btn sm" data-action="add-blank-row" data-scope="${scope}">${icon('plus')} Blank row</button><button class="btn sm" data-action="add-similar-row" data-scope="${scope}">${icon('copy')} Similar row</button><button class="btn sm" data-action="export-grid" data-scope="${scope}">${icon('download')} CSV</button>`:`<span class="chip green">Approved baseline</span><button class="btn sm" data-action="export-grid" data-scope="${scope}">${icon('download')} CSV</button>`;
    const footerCopy=editable?`<b>Smart Add Row:</b> Description, size, make/origin, unit and remarks can carry forward. Quantity, model/serial and cost start clean.`:`<b>Controlled revision:</b> This approved baseline is read-only. Start a new revision before changing material lines.`;
    return `<div class="table-shell">${showToolbar?`<div class="table-toolbar"><div class="toolbar-group">${project?`<span class="toolbar-label">Building</span><select class="select compact" data-action="plan-building" ${editable?'':'disabled'}>${project.buildings.map(b=>`<option value="${b.id}" ${b.id===project.plan.buildingId?'selected':''}>${esc(b.code)} — ${esc(b.name)}</option>`).join('')}</select>`:''}<span class="chip outline">${rows.length} row${rows.length===1?'':'s'}</span><span class="chip neutral">${editable?'Autosaved':'Revision v'+(project?.plan?.version||1)}</span></div><div class="toolbar-group">${toolbarActions}</div></div>`:''}<div class="table-scroll"><table class="data-grid"><thead><tr><th class="sno">S:No</th><th>Item Description</th><th>Size (If any)</th><th>Model/Serial No.</th><th>Make/Origin</th><th>QTY</th><th>Unit</th><th>Remarks</th>${costs?'<th>Unit Cost</th><th>Total Cost</th>':''}</tr></thead><tbody>${body}</tbody></table></div><div class="table-footer"><div>${footerCopy}</div><div class="totals"><span>Lines <b>${rows.length}</b></span>${costs?`<span>Total <b>${formatMoney(total)}</b></span>`:''}</div></div></div>`;
  }

  function projectPlanPage(project){
    const user=currentUser();
    const selected=project.plan.rows.find(row=>row.id===state.ui.selectedPlanRowId)||project.plan.rows[0];
    const canEdit=(user.role==='Engineer'&&project.plan.status!=='approved')||user.role==='Admin';
    const statusMap={draft:['Draft','neutral'],submitted:['Submitted','blue'],procurement_review:['Procurement review','amber'],ready_for_approval:['Ready for approval','purple'],approved:['Approved','green']};
    const [label,type]=statusMap[project.plan.status]||[project.plan.status,'neutral'];
    let primary='';
    if(project.plan.status==='draft'&&user.role==='Engineer') primary=`<button class="btn primary" data-action="submit-plan" data-project="${project.id}">Submit to Procurement ${icon('arrowRight')}</button>`;
    else if(project.plan.status==='procurement_review'&&(user.role==='Procurement'||user.role==='Admin')) primary=`<button class="btn primary" data-action="mark-plan-ready" data-project="${project.id}">Send for Engineer approval ${icon('arrowRight')}</button>`;
    else if(project.plan.status==='ready_for_approval'&&user.canApprove) primary=`<button class="btn success" data-action="approve-plan" data-project="${project.id}">${icon('check')} Approve and activate</button>`;
    else if(project.plan.status==='approved'&&(user.role==='Engineer'||user.role==='Admin')) primary=`<button class="btn" data-action="create-plan-revision" data-project="${project.id}">${icon('copy')} Start new revision</button>`;
    const content=`<div class="project-shell">${projectHero(project,'plan',`<button class="btn" data-action="export-grid" data-scope="plan">${icon('download')} Export CSV</button>${primary}`)}</div><div class="project-content">
      <div class="notice ${project.plan.status==='approved'?'green':project.plan.status==='procurement_review'?'amber':''}"><div class="notice-icon">${icon(project.plan.status==='approved'?'check':'activity')}</div><div><strong>Material plan v${project.plan.version} · ${esc(label)}</strong><p>${project.plan.status==='approved'?`Approved by ${project.plan.approvedBy} on ${project.plan.approvedAt}. The approved plan remains the baseline for Phase 2 requests.`:project.plan.status==='procurement_review'?`Procurement owner ${project.procurementOwner} is arranging stock and supplier items. Technical questions stay attached to the affected row.`:project.plan.status==='draft'&&project.plan.baselineVersion?`Revision v${project.plan.version} is being prepared. Approved v${project.plan.baselineVersion} remains the execution baseline until this revision is approved.`:'Build the requirement list using the same clean row format used in Material Requests.'}</p></div></div>
      <div class="split wide-right" style="margin-top:14px"><div>${canonicalTable(project.plan.rows,{scope:'plan',editable:canEdit,selectedId:selected?.id||'',showToolbar:true,project})}</div><aside class="sticky-rail"><div class="card"><div class="section-head"><div><h2>Plan control</h2><p>Status, owner and row conversation.</p></div>${chip(label,type)}</div><div class="section-body"><div class="fact-list"><div class="fact-row"><span>Prepared by</span><strong>${esc(project.plan.submittedBy||project.createdBy)}</strong></div><div class="fact-row"><span>Procurement</span><strong>${esc(project.plan.processedBy||project.procurementOwner)}</strong></div><div class="fact-row"><span>Approver</span><strong>${esc(project.plan.approvedBy||project.approver)}</strong></div><div class="fact-row"><span>Revision</span><strong>v${project.plan.version}</strong></div><div class="fact-row"><span>Building</span><strong>${esc(project.buildings.find(b=>b.id===project.plan.buildingId)?.code||'—')}</strong></div></div></div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>${selected?esc(selected.modelSerial||selected.description):'Row discussion'}</h2><p>Comments remain related to the selected line.</p></div></div><div class="section-body">${comments(project.id==='madinat'?[{actor:'Ali Raza',role:'Procurement',time:'20 Jul 2026, 14:16',text:'Please confirm duct gauge and attach the approved workshop layout.'}]:[{actor:'Ali Raza',role:'Procurement',time:'23 Jul 2026, 12:25',text:'Fan duty confirmed against the attached equipment schedule.'},{actor:'Imran Khan',role:'Engineer',time:'23 Jul 2026, 13:05',text:'Approved. Please proceed with Systemair or an equal approved make.'}])}<div class="comment-box"><input class="input compact" placeholder="Add a comment…"><button class="btn sm" data-action="add-comment">Send</button></div></div></div></aside></div>
    </div>`;
    return shell(content,'projects',['Projects',project.name,'Material Plan']);
  }

  function projectRequestsPage(project){
    const requests=state.requests.filter(r=>r.projectId===project.id);
    const content=`<div class="project-shell">${projectHero(project,'requests',`<button class="btn primary" data-route="requests/new">${icon('plus')} New material request</button>`)}</div><div class="project-content"><div class="card"><div class="section-head"><div><h2>Material requests</h2><p>Phase 2 execution needs linked to this project.</p></div><div class="toolbar-group"><select class="select compact"><option>All statuses</option><option>Open</option><option>Received</option></select><button class="btn sm">${icon('download')} Export</button></div></div><div class="list">${requests.map(request=>{const [label,type]=requestStatus(request.status);return `<div class="queue-card" data-route="request/${request.id}"><div><strong>${esc(request.id)} · ${esc(request.buildingCode)}</strong><p>${request.rows.length} lines · Requested by ${esc(request.requestedBy)} · ${esc(request.requestedAt)}</p></div><div class="small-stat"><span>Status</span>${chip(label,type)}</div><div class="small-stat"><span>Required</span>${esc(request.requiredDate)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')||'<div class="empty-state"><div class="empty-icon">'+icon('request')+'</div><h3>No requests yet</h3><p>Active projects can receive fast site material requests.</p></div>'}</div></div></div>`;
    return shell(content,'projects',['Projects',project.name,'Requests']);
  }

  function projectDocumentsPage(project){
    const content=`<div class="project-shell">${projectHero(project,'documents',`<button class="btn primary" data-action="upload-document">${icon('upload')} Upload document</button>`)}</div><div class="project-content"><div class="card"><div class="section-head"><div><h2>Document register</h2><p>Project, request, PO and delivery documents remain related to their source record.</p></div><button class="btn sm">${icon('download')} Export register</button></div><div class="section-body" style="padding:0"><table class="building-table"><thead><tr><th>Document</th><th>Type</th><th>Reference</th><th>Revision</th><th>Uploaded by</th><th>Date</th></tr></thead><tbody>${project.documents.map(doc=>`<tr><td><strong>${esc(doc.name)}</strong></td><td>${esc(doc.type)}</td><td>${esc(doc.ref)}</td><td>${chip(doc.revision,'neutral')}</td><td>${esc(doc.uploadedBy)}</td><td>${esc(doc.time)}</td></tr>`).join('')||'<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">'+icon('file')+'</div><h3>No documents uploaded</h3><p>Add drawings, schedules, submittals and approvals here.</p></div></td></tr>'}</tbody></table></div></div></div>`;
    return shell(content,'projects',['Projects',project.name,'Documents']);
  }
  function projectActivityPage(project){
    const content=`<div class="project-shell">${projectHero(project,'activity',`<button class="btn">${icon('download')} Export audit</button>`)}</div><div class="project-content"><div class="split"><div class="card"><div class="section-head"><div><h2>Project activity</h2><p>Immutable history of actions, actors and timestamps.</p></div></div><div class="section-body">${activityList(project.activity.slice().reverse())}</div></div><aside><div class="card"><div class="section-head"><div><h2>Audit principles</h2><p>Confidence through transparency.</p></div></div><div class="section-body"><div class="notice green"><div class="notice-icon">${icon('lock')}</div><div><strong>Append-only</strong><p>Corrections create a new event; previous entries remain visible.</p></div></div><div class="fact-list" style="margin-top:14px"><div class="fact-row"><span>Project created</span><strong>${esc(project.createdAt)}</strong></div><div class="fact-row"><span>Current revision</span><strong>Plan v${project.plan.version}</strong></div><div class="fact-row"><span>Last actor</span><strong>${esc(project.activity.at(-1)?.actor||'—')}</strong></div></div></div></div></aside></div></div>`;
    return shell(content,'projects',['Projects',project.name,'Activity']);
  }

  function requestsPage(){
    const user=currentUser();
    const items=state.requests.filter(r=>user.role!=='Engineer'||r.requestedBy===user.name||r.projectId==='nexus');
    const content=`<section class="page">${pageHeader('Execution requests','Material Requests','Fast site requests stay simple for Engineers and fully traceable for Procurement.',`<button class="btn primary" data-route="requests/new">${icon('plus')} New request</button>`)}<div class="grid three" style="margin-bottom:14px"><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('request')}</div>${chip('All','neutral')}</div><div><strong>${items.length}</strong><p>Total requests</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('activity')}</div>${chip('Open','amber')}</div><div><strong>${items.filter(r=>!['received','closed','cancelled'].includes(r.status)).length}</strong><p>In progress</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('check')}</div>${chip('Complete','green')}</div><div><strong>${items.filter(r=>r.status==='received').length}</strong><p>Received</p></div></div></div><div class="card"><div class="section-head"><div><h2>Request register</h2><p>Sort by priority, current owner, project or status.</p></div><div class="toolbar-group"><select class="select compact"><option>All projects</option><option>Nexus 4 Station</option></select><select class="select compact"><option>All statuses</option><option>Open</option><option>Received</option></select><button class="btn sm">${icon('download')} CSV</button></div></div><div class="list">${items.map(request=>{const [label,type]=requestStatus(request.status);return `<div class="queue-card" data-route="request/${request.id}"><div><strong>${esc(request.id)} · ${esc(request.projectName)} · ${esc(request.buildingCode)}</strong><p>${request.rows.length} lines · ${esc(request.priority)} · Requested by ${esc(request.requestedBy)}</p></div><div class="small-stat"><span>Status</span>${chip(label,type)}</div><div class="small-stat"><span>Current owner</span>${esc(request.currentOwner)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')}</div></div></section>`;
    return shell(content,'requests',['Material Requests']);
  }

  function newRequestPage(){
    const draft=state.ui.newRequest;
    const project=projectById(draft.projectId)||state.projects.find(p=>p.status==='active');
    const building=project?.buildings.find(b=>b.id===draft.buildingId)||project?.buildings[0];
    if(project&&!draft.projectId){draft.projectId=project.id;draft.buildingId=building?.id||'';}
    const costs=canSeeCosts();
    const content=`<section class="page">${pageHeader('Three clear steps','New Material Request','Select the active project, add the required material lines, and submit. Procurement receives the same rows without re-entering anything.',`<button class="btn" data-action="save-request-draft">Save draft</button>`)}<div class="stepper"><div class="step-pill active"><b>1</b> Project & building</div><div class="step-line"></div><div class="step-pill active"><b>2</b> Materials</div><div class="step-line"></div><div class="step-pill"><b>3</b> Review & submit</div></div><div class="request-layout"><div><div class="card" style="margin-bottom:14px"><div class="section-head"><div><h2>Request context</h2><p>Project references carry automatically into every downstream record.</p></div></div><div class="section-body"><div class="form-grid"><div class="form-group"><label>Active project</label><select class="select" data-new-request-field="projectId">${state.projects.filter(p=>p.status==='active').map(p=>`<option value="${p.id}" ${p.id===draft.projectId?'selected':''}>${esc(p.ref)} — ${esc(p.name)}</option>`).join('')}</select></div><div class="form-group"><label>Building</label><select class="select" data-new-request-field="buildingId">${project?.buildings.map(b=>`<option value="${b.id}" ${b.id===draft.buildingId?'selected':''}>${esc(b.code)} — ${esc(b.name)}</option>`).join('')}</select></div><div class="form-group"><label>Priority</label><select class="select" data-new-request-field="priority"><option ${draft.priority==='Normal'?'selected':''}>Normal</option><option ${draft.priority==='Urgent'?'selected':''}>Urgent</option></select></div><div class="form-group"><label>Required date</label><input class="input" type="date" value="${esc(draft.requiredDate)}" data-new-request-field="requiredDate"></div></div></div></div>${canonicalTable(draft.rows,{scope:'new-request',editable:true,selectedId:'',showToolbar:true})}</div><aside class="request-summary"><div class="card"><div class="section-head"><div><h2>Request summary</h2><p>What Procurement will receive.</p></div>${chip(draft.priority,draft.priority==='Urgent'?'red':'neutral')}</div><div class="section-body"><div class="summary-block"><label>Project</label><strong>${esc(project?.name||'Select project')}</strong><p>${esc(project?.ref||'')} · ${esc(building?.code||'')}</p></div><div class="summary-block"><label>Requested by</label><strong>${esc(currentUser().name)}</strong><p>${esc(currentUser().title)}</p></div><div class="summary-block"><label>Material lines</label><div class="summary-total"><span>${draft.rows.length} row${draft.rows.length===1?'':'s'}</span><b>${formatQty(draft.rows.reduce((sum,row)=>sum+Number(row.qty||0),0))}</b></div></div>${costs?`<div class="summary-block"><label>Estimated value</label><div class="summary-total"><span>Admin-enabled access</span><b>${formatMoney(draft.rows.reduce((sum,row)=>sum+Number(row.qty||0)*Number(row.unitCost||0),0))}</b></div></div>`:''}<div class="summary-block"><label>Note to Procurement</label><textarea class="textarea" data-new-request-field="notes" placeholder="Optional context, location or urgency note…">${esc(draft.notes)}</textarea></div><div class="notice green" style="margin-top:12px"><div class="notice-icon">${icon('link')}</div><div><strong>Rows stay connected</strong><p>Procurement can allocate warehouse stock, create an RFQ or create a PO from these exact lines.</p></div></div><div class="sticky-actions"><button class="btn primary" data-action="submit-new-request">Submit to Procurement ${icon('arrowRight')}</button><button class="btn" data-action="review-request">Review before submitting</button></div></div></div></aside></div></section>`;
    return shell(content,'requests',['Material Requests','New']);
  }

  function requestDetailPage(request){
    const [label,type]=requestStatus(request.status);
    const project=projectById(request.projectId);
    const isOffice=currentUser().role==='Procurement'||currentUser().role==='Admin';
    const fulfilled=Object.values(request.fulfilment||{}).reduce((sum,line)=>sum+line.received,0);
    const total=Object.values(request.fulfilment||{}).reduce((sum,line)=>sum+line.requested,0);
    const stages=[['submitted','Submitted'],['reviewed','Reviewed'],['sourcing','Sourcing'],['ordered','Ordered'],['received','Received']];
    const order={submitted:0,reviewed:1,sourcing:2,ordered:3,partial:4,received:4};
    const idx=order[request.status]??0;
    const content=`<section class="page"><div class="record-header"><div class="record-title"><div class="record-icon">${icon('request')}</div><div><span class="eyebrow">Material Request</span><h1>${esc(request.id)}</h1><div class="record-meta"><span>${esc(request.projectName)}</span><span>•</span><span>${esc(request.buildingCode)}</span><span>•</span>${chip(label,type)}${chip(request.priority,request.priority==='Urgent'?'red':'neutral')}</div></div></div><div class="page-actions"><button class="btn">${icon('download')} Export</button>${isOffice?`<button class="btn primary" data-route="procurement/${request.id}">Open procurement desk ${icon('arrowRight')}</button>`:''}</div></div><div class="card flat"><div class="lifecycle">${stages.map((s,i)=>`<div class="life-step ${i<idx?'done':i===idx?'current':''}"><div class="life-num">${i<idx?icon('check'):i+1}</div><div class="life-copy"><strong>${esc(s[1])}</strong><span>${i===0?request.requestedAt:i===idx?'Current stage':'Linked automatically'}</span></div></div>`).join('')}</div></div><div class="notice ${request.status==='received'?'green':'amber'}" style="margin-top:14px"><div class="notice-icon">${icon(request.status==='received'?'check':'activity')}</div><div><strong>${request.status==='received'?'Request complete':`Current owner: ${request.currentOwner}`}</strong><p>${request.status==='received'?'All requested quantities are confirmed received.':`${fulfilled} of ${total} total units are confirmed received. The field Engineer can see this status without calling Procurement.`}</p></div></div><div class="split" style="margin-top:14px"><div><div class="card"><div class="section-head"><div><h2>Requested materials</h2><p>The approved row format remains unchanged.</p></div></div><div class="section-body" style="padding:0">${canonicalTable(request.rows,{scope:'request-read',editable:false})}</div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Connected records</h2><p>Follow the same lines from request to order and receipt.</p></div></div><div class="section-body">${recordChain(request)}</div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Fulfilment by line</h2><p>Requested, ordered, received and remaining quantities are visible without changing the request table.</p></div></div><div class="section-body">${request.rows.map(row=>{const f=request.fulfilment[row.id]||{requested:row.qty,warehouse:0,external:row.qty,ordered:0,received:0};return `<div class="fulfilment-row"><div class="fulfilment-item"><strong>${esc(row.description)}</strong><span>${esc(row.modelSerial)} · ${esc(row.size)}</span></div><div class="qty-stat"><span>Requested</span><b>${f.requested}</b></div><div class="qty-stat"><span>Ordered</span><b>${f.ordered}</b></div><div class="qty-stat"><span>Received</span><b>${f.received}</b></div><div class="qty-stat"><span>Remaining</span><b>${Math.max(0,f.requested-f.received)}</b></div><div class="allocation">${f.warehouse?`<span class="alloc-pill stock">${f.warehouse} stock</span>`:''}${f.external?`<span class="alloc-pill vendor">${f.external} supplier</span>`:''}</div></div>`}).join('')}</div></div></div><aside class="sticky-rail"><div class="card"><div class="section-head"><div><h2>Request facts</h2><p>Responsibility and timing.</p></div></div><div class="section-body fact-list"><div class="fact-row"><span>Requested by</span><strong>${esc(request.requestedBy)}</strong></div><div class="fact-row"><span>Requested at</span><strong>${esc(request.requestedAt)}</strong></div><div class="fact-row"><span>Required date</span><strong>${esc(request.requiredDate)}</strong></div><div class="fact-row"><span>Current owner</span><strong>${esc(request.currentOwner)}</strong></div><div class="fact-row"><span>Project</span><strong>${esc(project?.ref||'')} · ${esc(request.buildingCode)}</strong></div></div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Discussion</h2><p>Field and office communication stays attached.</p></div></div><div class="section-body">${comments(request.comments)}<div class="comment-box"><input class="input compact" placeholder="Add a comment…"><button class="btn sm" data-action="add-comment">Send</button></div></div></div></aside></div></section>`;
    return shell(content,'requests',['Material Requests',request.id]);
  }

  function procurementQueuePage(){
    const open=state.requests.filter(r=>!['received','closed','cancelled'].includes(r.status));
    const plans=state.projects.filter(p=>['submitted','procurement_review','ready_for_approval'].includes(p.status));
    const content=`<section class="page">${pageHeader('Office action desk','Procurement','A single queue for project-plan arrangement, field requests, supplier sourcing, purchase orders and delivery follow-up.',`<button class="btn">${icon('filter')} Saved views</button><button class="btn primary" data-route="procurement/MR-2026-024">Open current sourcing ${icon('arrowRight')}</button>`)}<div class="grid four metric-grid"><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('folder')}</div>${chip('Phase 1','amber')}</div><div><strong>${plans.length}</strong><p>Plans awaiting action</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('request')}</div>${chip('Execution','blue')}</div><div><strong>${open.length}</strong><p>Open site requests</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('order')}</div>${chip('Linked','purple')}</div><div><strong>${state.purchaseOrders.length}</strong><p>Purchase orders</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('truck')}</div>${chip('Attention','amber')}</div><div><strong>${state.purchaseOrders.filter(po=>po.status!=='Received').length}</strong><p>Deliveries in progress</p></div></div></div><div class="queue-grid" style="margin-top:14px"><div><div class="card"><div class="section-head"><div><h2>Priority queue</h2><p>What needs Procurement action now.</p></div><div class="toolbar-group"><select class="select compact"><option>All projects</option><option>Nexus 4 Station</option></select><select class="select compact"><option>By urgency</option><option>By required date</option></select></div></div><div class="list">${plans.map(project=>{const [label,type]=projectStatus(project.status);return `<div class="queue-card" data-route="project/${project.id}/plan"><div><strong>Phase 1 plan · ${esc(project.name)}</strong><p>${project.plan.rows.length} lines · Created by ${esc(project.createdBy)} · Approver ${esc(project.approver)}</p></div><div class="small-stat"><span>Status</span>${chip(label,type)}</div><div class="small-stat"><span>Current owner</span>${esc(project.procurementOwner)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')}${open.map(request=>{const [label,type]=requestStatus(request.status);return `<div class="queue-card" data-route="procurement/${request.id}"><div><strong>${esc(request.id)} · ${esc(request.projectName)} · ${esc(request.buildingCode)}</strong><p>${request.rows.length} lines · ${esc(request.priority)} · Required ${esc(request.requiredDate)}</p></div><div class="small-stat"><span>Status</span>${chip(label,type)}</div><div class="small-stat"><span>Owner</span>${esc(request.currentOwner)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')}</div></div></div><aside><div class="card"><div class="section-head"><div><h2>Saved views</h2><p>Stripe-style operational filters.</p></div></div><div class="section-body list"><div class="list-row"><span class="status-dot red"></span><div class="grow"><strong>Urgent and overdue</strong><span>1 request</span></div></div><div class="list-row"><span class="status-dot blue"></span><div class="grow"><strong>RFQ required</strong><span>2 lines</span></div></div><div class="list-row"><span class="status-dot amber"></span><div class="grow"><strong>Partial receipts</strong><span>1 purchase order</span></div></div><div class="list-row"><span class="status-dot green"></span><div class="grow"><strong>Ready to close</strong><span>1 request</span></div></div></div></div><div class="notice green" style="margin-top:14px"><div class="notice-icon">${icon('lock')}</div><div><strong>Commercial access</strong><p>${canSeeCosts()?'Enabled for Ali Raza by Admin.':'Not enabled for this account.'} Role and capability are both checked.</p></div></div></aside></div></section>`;
    return shell(content,'procurement',['Procurement']);
  }

  function procurementRequestPage(request){
    const tab=state.ui.procurementTab||'fulfilment';
    const [label,type]=requestStatus(request.status);
    const project=projectById(request.projectId);
    const costs=canSeeCosts();
    const tabs=[['fulfilment','Fulfilment'],['quotes','Quote comparison'],['orders','Orders'],['activity','Activity & comments']];
    let body='';
    if(tab==='fulfilment'){
      body=`<div class="split wide-right"><div><div class="card"><div class="section-head"><div><h2>Source each request line</h2><p>Split a line between warehouse stock and suppliers without changing the original request.</p></div><button class="btn sm" data-action="auto-allocate">${icon('refresh')} Auto-check inventory</button></div><div class="section-body">${request.rows.map(row=>{const f=request.fulfilment[row.id]||{requested:row.qty,warehouse:0,external:row.qty,ordered:0,received:0};return `<div class="fulfilment-row"><div class="fulfilment-item"><strong>${esc(row.description)}</strong><span>${esc(row.modelSerial)} · ${esc(row.size)} · ${esc(row.makeOrigin)}</span></div><div class="qty-stat"><span>Requested</span><b>${f.requested}</b></div><div class="qty-stat"><span>Warehouse</span><b>${f.warehouse}</b></div><div class="qty-stat"><span>External</span><b>${f.external}</b></div><div class="qty-stat"><span>Remaining</span><b>${Math.max(0,f.requested-f.received)}</b></div><div class="allocation"><button class="alloc-pill stock" data-action="allocate-stock" data-request="${request.id}" data-row="${row.id}">${f.warehouse} stock</button><button class="alloc-pill vendor" data-action="allocate-vendor" data-request="${request.id}" data-row="${row.id}">${f.external} supplier</button></div></div>`}).join('')}</div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Original request lines</h2><p>Read-only source document.</p></div></div><div class="section-body" style="padding:0">${canonicalTable(request.rows,{scope:'proc-read',editable:false})}</div></div></div><aside class="sticky-rail"><div class="card"><div class="section-head"><div><h2>Next action</h2><p>Complete supplier sourcing.</p></div>${chip(label,type)}</div><div class="section-body"><div class="notice amber"><div class="notice-icon">${icon('quote')}</div><div><strong>2 lines require supplier quotes</strong><p>MFD and fire-rated sealant are linked to RFQ-2026-048.</p></div></div><div class="sticky-actions"><button class="btn primary" data-proc-tab="quotes">Compare supplier quotes ${icon('arrowRight')}</button><button class="btn" data-action="create-rfq">${icon('plus')} Create another RFQ</button></div></div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Request context</h2><p>Field need and responsibility.</p></div></div><div class="section-body fact-list"><div class="fact-row"><span>Requested by</span><strong>${esc(request.requestedBy)}</strong></div><div class="fact-row"><span>Project / Building</span><strong>${esc(project.ref)} · ${esc(request.buildingCode)}</strong></div><div class="fact-row"><span>Required date</span><strong>${esc(request.requiredDate)}</strong></div><div class="fact-row"><span>Priority</span><strong>${chip(request.priority,request.priority==='Urgent'?'red':'neutral')}</strong></div></div></div></aside></div>`;
    } else if(tab==='quotes'){
      const supplierHeaders=state.rfq.suppliers.map(s=>`<th class="supplier"><strong>${esc(s.name)}</strong><div class="quote-meta">${esc(s.quoteRef)} · ${s.leadDays} day lead · valid ${esc(s.validity)}</div></th>`).join('');
      const quoteRows=request.rows.filter(row=>state.rfq.prices[row.id]).map(row=>`<tr><td><strong>${esc(row.description)}</strong><div class="quote-meta">${esc(row.modelSerial)} · ${esc(row.size)} · Qty ${row.qty}</div></td>${state.rfq.suppliers.map(s=>{const price=state.rfq.prices[row.id][s.id];const selected=state.rfq.selected[row.id]===s.id;return `<td><div class="quote-price">${costs?formatMoney(price):'Protected'}</div><div class="quote-meta">Total ${costs?formatMoney(price*row.qty):'—'}</div><div class="quote-choice"><label class="chip ${selected?'green':'outline'}"><input type="radio" name="quote-${row.id}" value="${s.id}" data-select-quote data-row="${row.id}" ${selected?'checked':''} style="display:none">${selected?'Selected':'Choose'}</label></div></td>`}).join('')}</tr>`).join('');
      body=`<div class="split wide-right"><div><div class="card"><div class="section-head"><div><h2>Supplier quote comparison</h2><p>Compare approved suppliers side by side and select per line.</p></div>${chip(state.rfq.id,'blue')}</div><div class="section-body" style="padding:0"><div class="quote-scroll"><table class="quote-table"><thead><tr><th>Requested line</th>${supplierHeaders}</tr></thead><tbody>${quoteRows}</tbody></table></div></div></div><div class="notice green" style="margin-top:14px"><div class="notice-icon">${icon('link')}</div><div><strong>Selected quotes remain related to ${esc(request.id)}</strong><p>Creating purchase orders copies the approved quantities and supplier selection. No one types the material lines again.</p></div></div></div><aside class="sticky-rail"><div class="card"><div class="section-head"><div><h2>Commercial summary</h2><p>Visible only with Admin-granted capability.</p></div>${chip(costs?'Access enabled':'Protected',costs?'green':'neutral')}</div><div class="section-body"><div class="fact-list"><div class="fact-row"><span>Selected suppliers</span><strong>${new Set(Object.values(state.rfq.selected)).size}</strong></div><div class="fact-row"><span>Selected total</span><strong>${costs?formatMoney(Object.entries(state.rfq.selected).reduce((sum,[rowId,supplierId])=>{const row=request.rows.find(r=>r.id===rowId);return sum+(state.rfq.prices[rowId]?.[supplierId]||0)*(row?.qty||0)},0)):'Hidden'}</strong></div><div class="fact-row"><span>Required date</span><strong>${esc(request.requiredDate)}</strong></div></div><div class="sticky-actions"><button class="btn primary" data-action="create-pos">Create purchase orders ${icon('arrowRight')}</button><button class="btn">Save selection</button></div></div></div></aside></div>`;
    } else if(tab==='orders'){
      const pos=state.purchaseOrders.filter(po=>po.requestId===request.id);
      body=`<div class="card"><div class="section-head"><div><h2>Purchase orders created from this request</h2><p>Each PO retains source request, project, building and request-line references.</p></div><button class="btn primary" data-action="create-pos">${icon('plus')} Create PO</button></div><div class="list">${pos.map(po=>`<div class="queue-card" data-route="po/${po.id}"><div><strong>${esc(po.id)} · ${esc(po.supplier)}</strong><p>${po.items.length} line${po.items.length===1?'':'s'} · Revision ${po.revision} · Created by ${esc(po.createdBy)}</p></div><div class="small-stat"><span>Status</span>${chip(po.status,po.status.includes('Partially')?'amber':'purple')}</div><div class="small-stat"><span>Required</span>${esc(po.requiredDate)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`).join('')||'<div class="empty-state"><div class="empty-icon">'+icon('order')+'</div><h3>No orders yet</h3><p>Select supplier quotes and create purchase orders without re-entering lines.</p></div>'}</div></div>`;
    } else {
      body=`<div class="split"><div class="card"><div class="section-head"><div><h2>Activity history</h2><p>Every procurement action and downstream document link.</p></div></div><div class="section-body">${activityList(request.activity.slice().reverse())}</div></div><aside><div class="card"><div class="section-head"><div><h2>Discussion</h2><p>Field, Procurement and Approver conversation.</p></div></div><div class="section-body">${comments(request.comments)}<div class="comment-box"><input class="input compact" placeholder="Add a comment…"><button class="btn sm" data-action="add-comment">Send</button></div></div></div></aside></div>`;
    }
    const content=`<section class="page"><div class="record-header"><div class="record-title"><div class="record-icon">${icon('procurement')}</div><div><span class="eyebrow">Procurement package</span><h1>${esc(request.id)}</h1><div class="record-meta"><span>${esc(request.projectName)}</span><span>•</span><span>${esc(request.buildingCode)}</span><span>•</span>${chip(label,type)}${chip(request.priority,request.priority==='Urgent'?'red':'neutral')}</div></div></div><div class="page-actions"><button class="btn" data-route="request/${request.id}">${icon('eye')} View field request</button><button class="btn">${icon('download')} Export package</button></div></div><div class="card flat"><div class="section-body">${recordChain(request)}</div></div><div class="record-tabs">${tabs.map(([id,name])=>`<button class="record-tab ${tab===id?'active':''}" data-proc-tab="${id}">${esc(name)}</button>`).join('')}</div>${body}</section>`;
    return shell(content,'procurement',['Procurement',request.id]);
  }

  function ordersPage(){
    const content=`<section class="page">${pageHeader('Purchase control','Purchase Orders','Orders remain linked to their source request, selected supplier quote and delivery receipts.',`<button class="btn">${icon('download')} Export register</button><button class="btn primary" data-route="procurement">Open sourcing queue</button>`)}<div class="project-list"><div class="project-row header"><div>Purchase order</div><div>Status</div><div>Supplier</div><div>Request</div><div>Required</div><div></div></div>${state.purchaseOrders.map(po=>`<div class="project-row" data-route="po/${po.id}"><div class="project-main"><div class="mark">PO</div><div><strong>${esc(po.id)}</strong><span>${po.items.length} line${po.items.length===1?'':'s'} · Revision ${po.revision} · ${esc(po.createdAt)}</span></div></div><div>${chip(po.status,po.status.includes('Partially')?'amber':'purple')}</div><div class="value">${esc(po.supplier)}</div><div class="value">${esc(po.requestId)}</div><div class="value">${esc(po.requiredDate)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`).join('')}</div></section>`;
    return shell(content,'orders',['Purchase Orders']);
  }

  function deliveriesPage(){
    const lines=state.purchaseOrders.flatMap(po=>po.items.map(item=>({...item,poId:po.id,supplier:po.supplier,status:po.status,requiredDate:po.requiredDate})));
    const content=`<section class="page">${pageHeader('Receiving control','Deliveries','Track ordered, received and remaining quantities, then attach delivery notes and packing slips from site.',`<button class="btn">${icon('camera')} Capture delivery slip</button>`)}<div class="card"><div class="section-head"><div><h2>Open delivery lines</h2><p>Partial receipts stay open until the remaining quantity arrives or is formally closed.</p></div></div><div class="section-body">${lines.map(line=>`<div class="receipt-line" data-route="po/${line.poId}"><div><strong>${esc(line.description)}</strong><small>${esc(line.poId)} · ${esc(line.supplier)} · ${esc(line.size)}</small></div><div><label>Ordered</label><b>${line.ordered}</b></div><div><label>Received</label><b>${line.received}</b></div><div><label>Remaining</label><b>${Math.max(0,line.ordered-line.received)}</b></div><div>${chip(line.status,line.status.includes('Partially')?'amber':'purple')}</div></div>`).join('')}</div></div></section>`;
    return shell(content,'deliveries',['Deliveries']);
  }

  function purchaseOrderPage(po){
    const request=requestById(po.requestId);
    const ordered=po.items.reduce((s,i)=>s+i.ordered,0),received=po.items.reduce((s,i)=>s+i.received,0);
    const content=`<section class="page"><div class="record-header"><div class="record-title"><div class="record-icon">${icon('order')}</div><div><span class="eyebrow">Purchase Order</span><h1>${esc(po.id)}</h1><div class="record-meta"><span>${esc(po.supplier)}</span><span>•</span><span>Revision ${po.revision}</span><span>•</span>${chip(po.status,po.status.includes('Partially')?'amber':'purple')}</div></div></div><div class="page-actions"><button class="btn">${icon('download')} Download PO</button><button class="btn primary" data-action="receive-po" data-po="${po.id}">${icon('truck')} Record receipt</button></div></div><div class="card flat"><div class="section-body">${recordChain(request)}</div></div><div class="receipt-grid" style="margin-top:14px"><div><div class="card"><div class="section-head"><div><h2>Order and receipt quantities</h2><p>Receive partially, record condition and keep the outstanding quantity visible.</p></div><div>${chip(`${received} of ${ordered} received`,received===ordered?'green':'amber')}</div></div><div class="section-body">${po.items.map(item=>`<div class="receipt-line"><div><strong>${esc(item.description)}</strong><small>${esc(item.modelSerial)} · ${esc(item.size)} · ${esc(item.unit)}</small></div><div><label>Ordered</label><b>${item.ordered}</b></div><div><label>Received</label><b>${item.received}</b></div><div><label>Remaining</label><b>${Math.max(0,item.ordered-item.received)}</b></div><div>${chip(item.received===item.ordered?'Complete':'Partial',item.received===item.ordered?'green':'amber')}</div></div>`).join('')}</div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Documents</h2><p>PO revisions, delivery notes and certificates stay attached.</p></div><button class="btn sm" data-action="upload-document">${icon('upload')} Add document</button></div><div class="section-body list">${po.documents.map(doc=>`<div class="list-row"><div class="metric-icon">${icon('file')}</div><div class="grow"><strong>${esc(doc.name)}</strong><span>${esc(doc.type)} · Uploaded by ${esc(doc.uploadedBy)} · ${esc(doc.time)}</span></div><button class="btn icon-only sm ghost">${icon('download')}</button></div>`).join('')}</div></div></div><aside class="sticky-rail"><div class="card"><div class="section-head"><div><h2>PO facts</h2><p>Source, owner and commercial control.</p></div></div><div class="section-body fact-list"><div class="fact-row"><span>Source request</span><strong>${esc(po.requestId)}</strong></div><div class="fact-row"><span>Project / Building</span><strong>${esc(request.projectName)} · ${esc(request.buildingCode)}</strong></div><div class="fact-row"><span>Created by</span><strong>${esc(po.createdBy)}</strong></div><div class="fact-row"><span>Required date</span><strong>${esc(po.requiredDate)}</strong></div><div class="fact-row"><span>Order value</span><strong>${canSeeCosts()?formatMoney(po.items.reduce((s,i)=>s+i.ordered*i.unitCost,0)):'Protected by Admin'}</strong></div></div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Revision history</h2><p>Earlier values are never destroyed.</p></div></div><div class="section-body">${activityList(po.history.slice().reverse())}</div></div></aside></div></section>`;
    return shell(content,'orders',['Purchase Orders',po.id]);
  }

  function projectProcurementPage(project){
    const requests=state.requests.filter(r=>r.projectId===project.id);
    const pos=state.purchaseOrders.filter(po=>requests.some(r=>r.id===po.requestId));
    const content=`<div class="project-shell">${projectHero(project,'procurement',`<button class="btn primary" data-route="procurement">Open office queue</button>`)}</div><div class="project-content"><div class="grid three"><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('request')}</div>${chip('Linked','blue')}</div><div><strong>${requests.length}</strong><p>Material requests</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('quote')}</div>${chip('Supplier','blue')}</div><div><strong>${requests.reduce((s,r)=>s+r.linked.rfqs.length,0)}</strong><p>RFQs</p></div></div><div class="card metric-card"><div class="metric-top"><div class="metric-icon">${icon('order')}</div>${chip('Orders','purple')}</div><div><strong>${pos.length}</strong><p>Purchase orders</p></div></div></div><div class="card" style="margin-top:14px"><div class="section-head"><div><h2>Project procurement records</h2><p>Requests and downstream orders remain connected to ${esc(project.ref)}.</p></div></div><div class="list">${requests.map(r=>{const [label,type]=requestStatus(r.status);return `<div class="queue-card" data-route="procurement/${r.id}"><div><strong>${esc(r.id)} · ${esc(r.buildingCode)}</strong><p>${r.rows.length} lines · ${r.linked.rfqs.length} RFQ · ${r.linked.pos.length} PO · ${r.linked.receipts.length} receipt</p></div><div class="small-stat"><span>Status</span>${chip(label,type)}</div><div class="small-stat"><span>Owner</span>${esc(r.currentOwner)}</div><button class="btn icon-only sm ghost">${icon('chevronRight')}</button></div>`}).join('')}</div></div></div>`;
    return shell(content,'projects',['Projects',project.name,'Procurement']);
  }

  function ensureWizard(){
    if(state.ui.wizardDraft) return state.ui.wizardDraft;
    state.ui.wizardDraft={
      ref:'YRA-',name:'',client:'',contractNo:'',location:'',startDate:'',endDate:'',notes:'',consultant:'',mainContractor:'',subcontractors:[''],otherContractors:[''],assignedEngineer:'Omar Farooq',approver:'Imran Khan',buildings:[{id:uid('b'),code:'',name:'',floors:'',hasFRP:false}],attachments:[]
    };
    return state.ui.wizardDraft;
  }
  function projectWizardPage(){
    const draft=ensureWizard();
    const step=state.ui.wizardStep||1;
    const steps=['Project details','Parties','Buildings','Attachments','Review'];
    let body='';
    if(step===1){
      body=`<div class="form-grid"><div class="form-group"><label>Yorks Reference / Ref. No.</label><input class="input" data-wizard-field="ref" value="${esc(draft.ref)}" placeholder="YRA-329"><span class="hint">Unique project reference used on every related record.</span></div><div class="form-group"><label>Project Name</label><input class="input" data-wizard-field="name" value="${esc(draft.name)}" placeholder="Project name"></div><div class="form-group"><label>Client</label><input class="input" data-wizard-field="client" value="${esc(draft.client)}" placeholder="Client company"></div><div class="form-group"><label>Contract / Job No.</label><input class="input" data-wizard-field="contractNo" value="${esc(draft.contractNo)}" placeholder="N-00000.0"></div><div class="form-group full"><label>Site Location</label><input class="input" data-wizard-field="location" value="${esc(draft.location)}" placeholder="Area, city and site description"></div><div class="form-group"><label>Start Date</label><input class="input" type="date" data-wizard-field="startDate" value="${esc(draft.startDate)}"></div><div class="form-group"><label>Expected End Date <span class="subtle">optional</span></label><input class="input" type="date" data-wizard-field="endDate" value="${esc(draft.endDate)}"></div><div class="form-group full"><label>Project Notes <span class="subtle">optional</span></label><textarea class="textarea" data-wizard-field="notes" placeholder="Scope, access, programme or special instructions">${esc(draft.notes)}</textarea></div></div>`;
    } else if(step===2){
      body=`<div class="form-grid"><div class="form-group"><label>Consultant</label><input class="input" data-wizard-field="consultant" value="${esc(draft.consultant)}" placeholder="Consultant company"></div><div class="form-group"><label>Main Contractor</label><input class="input" data-wizard-field="mainContractor" value="${esc(draft.mainContractor)}" placeholder="Main contractor / EPC"></div><div class="form-group"><label>Assigned Engineer</label><select class="select" data-wizard-field="assignedEngineer">${state.users.filter(u=>u.role==='Engineer').map(u=>`<option ${u.name===draft.assignedEngineer?'selected':''}>${esc(u.name)} — ${esc(u.title)}</option>`).join('')}</select></div><div class="form-group"><label>Technical Approver</label><select class="select" data-wizard-field="approver">${state.users.filter(u=>u.canApprove).map(u=>`<option ${u.name===draft.approver?'selected':''}>${esc(u.name)} — ${esc(u.title)}</option>`).join('')}</select></div><div class="form-group full"><label>Subcontractors <span class="subtle">if any</span></label>${draft.subcontractors.map((name,i)=>`<div class="inline" style="margin-bottom:7px"><input class="input" data-wizard-array="subcontractors" data-index="${i}" value="${esc(name)}" placeholder="Subcontractor company"><button class="btn icon-only" data-action="remove-wizard-array" data-key="subcontractors" data-index="${i}">${icon('x')}</button></div>`).join('')}<button class="btn sm" data-action="add-wizard-array" data-key="subcontractors">${icon('plus')} Add subcontractor</button></div><div class="form-group full"><label>Other Contractors <span class="subtle">if any</span></label>${draft.otherContractors.map((name,i)=>`<div class="inline" style="margin-bottom:7px"><input class="input" data-wizard-array="otherContractors" data-index="${i}" value="${esc(name)}" placeholder="Other contractor company"><button class="btn icon-only" data-action="remove-wizard-array" data-key="otherContractors" data-index="${i}">${icon('x')}</button></div>`).join('')}<button class="btn sm" data-action="add-wizard-array" data-key="otherContractors">${icon('plus')} Add contractor</button></div></div>`;
    } else if(step===3){
      body=`<div class="notice"><div class="notice-icon">${icon('building')}</div><div><strong>Multiple buildings are first-class project records</strong><p>Floor information is optional. Each building has one simple FRP Room Yes / No decision.</p></div></div><div style="margin-top:14px">${draft.buildings.map((b,i)=>`<div class="building-editor"><div class="building-editor-head"><strong>Building ${i+1}</strong><button class="btn icon-only sm ghost" data-action="remove-building" data-index="${i}">${icon('x')}</button></div><div class="building-editor-body"><div class="form-group"><label>Code</label><input class="input compact" data-building-field="code" data-index="${i}" value="${esc(b.code)}" placeholder="DF3W"></div><div class="form-group"><label>Building Name</label><input class="input compact" data-building-field="name" data-index="${i}" value="${esc(b.name)}" placeholder="Building name"></div><div class="form-group"><label>Floors / Levels <span class="subtle">optional</span></label><input class="input compact" data-building-field="floors" data-index="${i}" value="${esc(b.floors)}" placeholder="GF, 1F, Roof"></div><div class="form-group"><label>Has FRP Room?</label><div class="toggle"><button class="${b.hasFRP?'on':''}" data-action="toggle-frp" data-index="${i}" aria-label="Toggle FRP"></button><span>${b.hasFRP?'Yes':'No'}</span></div></div></div></div>`).join('')}</div><button class="btn" data-action="add-building">${icon('plus')} Add another building</button>`;
    } else if(step===4){
      body=`<div class="upload-zone" data-action="upload-document">${icon('upload')}<strong>Drop project files here or browse</strong><span>Drawings, contract, BOQ, schedules, approvals and site photographs</span></div><div class="notice green" style="margin-top:14px"><div class="notice-icon">${icon('link')}</div><div><strong>Documents stay contextual</strong><p>Files can later be linked to a project, building, material row, request, PO or delivery receipt without duplicating them.</p></div></div>${draft.attachments.length?`<div class="list" style="margin-top:14px">${draft.attachments.map(file=>`<div class="list-row"><div class="metric-icon">${icon('file')}</div><div class="grow"><strong>${esc(file.name)}</strong><span>${esc(file.type)} · Draft upload</span></div></div>`).join('')}</div>`:''}`;
    } else {
      body=`<div class="review-grid"><div class="review-block"><h4>Project identity</h4><div class="review-row"><span>Yorks Ref.</span><b>${esc(draft.ref||'Not set')}</b></div><div class="review-row"><span>Project Name</span><b>${esc(draft.name||'Not set')}</b></div><div class="review-row"><span>Client</span><b>${esc(draft.client||'Not set')}</b></div><div class="review-row"><span>Contract No.</span><b>${esc(draft.contractNo||'Not set')}</b></div><div class="review-row"><span>Location</span><b>${esc(draft.location||'Not set')}</b></div></div><div class="review-block"><h4>Responsibility</h4><div class="review-row"><span>Created by</span><b>${esc(currentUser().name)}</b></div><div class="review-row"><span>Assigned Engineer</span><b>${esc(draft.assignedEngineer)}</b></div><div class="review-row"><span>Technical Approver</span><b>${esc(draft.approver)}</b></div><div class="review-row"><span>Consultant</span><b>${esc(draft.consultant||'Not set')}</b></div><div class="review-row"><span>Main Contractor</span><b>${esc(draft.mainContractor||'Not set')}</b></div></div><div class="review-block"><h4>Buildings</h4>${draft.buildings.map(b=>`<div class="review-row"><span>${esc(b.code||'No code')}</span><b>${esc(b.name||'Unnamed')} · FRP ${b.hasFRP?'Yes':'No'}</b></div>`).join('')}</div><div class="review-block"><h4>What happens next</h4><div class="review-row"><span>1</span><b>Project created as Draft</b></div><div class="review-row"><span>2</span><b>Add Phase 1 material plan</b></div><div class="review-row"><span>3</span><b>Procurement arranges and comments</b></div><div class="review-row"><span>4</span><b>Engineer approves</b></div><div class="review-row"><span>5</span><b>Project becomes Active</b></div></div></div><div class="notice green" style="margin-top:14px"><div class="notice-icon">${icon('check')}</div><div><strong>Create once, use everywhere</strong><p>The project reference, buildings and responsible people will flow automatically into plans, requests, RFQs, purchase orders, receipts and reports.</p></div></div>`;
    }
    const content=`<section class="page">${pageHeader('V5 foundation, refined','Create Project','A complete five-step setup that remains calm and familiar. Save as draft at any time.',`<button class="btn" data-action="save-project-draft">Save draft</button>`)}<div class="wizard"><aside class="wizard-side"><h3>Project setup</h3><p>Complete only what is known. Optional information can be added later without blocking work.</p><div class="wizard-steps">${steps.map((name,i)=>`<div class="wizard-step ${i+1===step?'active':i+1<step?'done':''}"><b>${i+1<step?icon('check'):i+1}</b>${esc(name)}</div>`).join('')}</div></aside><div class="wizard-main"><div class="wizard-head"><span class="eyebrow">Step ${step} of 5</span><h2>${esc(steps[step-1])}</h2><p>${step===1?'Start with the project identity used on every document.':step===2?'Record organisations and clear responsibility.':step===3?'Add one or many buildings.':step===4?'Attach supporting project information.':'Confirm the setup and create the project draft.'}</p></div><div class="wizard-body">${body}</div><div class="wizard-foot"><button class="btn ${step===1?'ghost':''}" data-action="wizard-back" ${step===1?'disabled':''}>${icon('arrowLeft')} Back</button>${step<5?`<button class="btn primary" data-action="wizard-next">Continue ${icon('arrowRight')}</button>`:`<button class="btn success" data-action="create-project">${icon('check')} Create project & add materials</button>`}</div></div></div></section>`;
    return shell(content,'projects',['Projects','Create']);
  }

  function closeModal(){ portal.innerHTML=''; state.ui.commandOpen=false; }
  function showModal({title,description='',body='',foot='',size=''}){
    portal.innerHTML=`<div class="modal-backdrop" data-modal-backdrop><div class="modal ${size}" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${description?`<p>${esc(description)}</p>`:''}</div><button class="modal-close" data-action="close-modal">${icon('x')}</button></div><div class="modal-body">${body}</div>${foot?`<div class="modal-foot">${foot}</div>`:''}</div></div>`;
  }
  function openPicker(target='new-request'){
    state.ui.pickerTarget=target;
    state.ui.pickerSelected=[];
    state.ui.pickerCategory='all';
    state.ui.pickerSearch='';
    renderPicker();
  }
  function pickerFiltered(){
    const q=state.ui.pickerSearch.toLowerCase().trim();
    return materials.filter(m=>(state.ui.pickerCategory==='all'||m.categoryId===state.ui.pickerCategory)&&(!q||[m.code,m.description,m.size,m.model,m.makeOrigin].some(v=>String(v).toLowerCase().includes(q))));
  }
  function renderPicker(){
    const list=pickerFiltered();
    const selected=state.ui.pickerSelected.map(id=>materials.find(m=>m.id===id)).filter(Boolean);
    const body=`<div class="picker"><aside class="finder-side"><div class="finder-section-title">Categories</div><button class="finder-category ${state.ui.pickerCategory==='all'?'active':''}" data-picker-category="all">${icon('grid')} All materials <span class="count">${materials.length}</span></button>${categories.map(cat=>`<button class="finder-category ${state.ui.pickerCategory===cat.id?'active':''}" data-picker-category="${cat.id}">${icon(cat.icon)} ${esc(cat.name)} <span class="count">${materials.filter(m=>m.categoryId===cat.id).length}</span></button>`).join('')}</aside><div class="picker-center"><div class="finder-bar"><div class="searchbox">${icon('search')}<input data-picker-search value="${esc(state.ui.pickerSearch)}" placeholder="Search materials…"></div><button class="btn sm" data-action="add-custom-from-picker">${icon('plus')} Custom item</button></div><div class="picker-list">${list.map(item=>{const isSelected=state.ui.pickerSelected.includes(item.id);return `<div class="picker-item ${isSelected?'selected':''}" data-picker-item="${item.id}"><div class="material-icon">${esc(item.code.split('-')[0].slice(0,3))}</div><div style="min-width:0"><strong>${esc(item.description)}</strong><span>${esc(item.code)} · ${esc(item.size)} · ${esc(item.makeOrigin)}</span><span>${formatQty(Math.max(0,item.stock-item.allocated))} ${esc(item.unit)} available</span></div><div class="check">${icon('check')}</div></div>`}).join('')}</div></div><aside class="picker-tray"><h4>Selected materials</h4>${selected.length?`<div class="tray-list">${selected.map(item=>`<div class="tray-row"><div class="material-icon">${esc(item.code.split('-')[0].slice(0,3))}</div><div class="grow"><strong>${esc(item.description)}</strong><span>${esc(item.size)} · ${esc(item.unit)}</span></div><button class="row-menu" data-picker-item="${item.id}">${icon('x')}</button></div>`).join('')}</div>`:`<div class="tray-empty">Select one or more catalogue items. They will be added as clean rows using the approved columns.</div>`}</aside></div>`;
    showModal({title:'Add materials',description:'Use the same approved catalogue for project plans and site requests.',body,foot:`<button class="btn" data-action="close-modal">Cancel</button><button class="btn primary" data-action="confirm-picker" ${selected.length?'':'disabled'}>Add ${selected.length||''} material${selected.length===1?'':'s'} ${icon('arrowRight')}</button>`,size:'lg'});
    setTimeout(()=>document.querySelector('[data-picker-search]')?.focus(),20);
  }
  function openSizeBuilder(scope,rowId){
    state.ui.sizeTarget={scope,rowId};
    state.ui.sizeMode='rectangular';
    renderSizeBuilder();
  }
  function rowFromScope(scope,rowId){
    if(scope==='new-request') return state.ui.newRequest.rows.find(r=>r.id===rowId);
    if(scope==='plan') return projectById(state.ui.projectId||route()[1]||'nexus')?.plan.rows.find(r=>r.id===rowId);
    return null;
  }
  function renderSizeBuilder(){
    const target=state.ui.sizeTarget;
    const row=rowFromScope(target.scope,target.rowId)||{};
    const mode=state.ui.sizeMode;
    let fields='';
    if(mode==='rectangular') fields=`<div class="form-grid"><div class="form-group"><label>Width</label><input class="input" type="number" data-size-field="width" value="500"></div><div class="form-group"><label>Height</label><input class="input" type="number" data-size-field="height" value="500"></div><div class="form-group full"><label>Unit</label><select class="select" data-size-field="unit"><option>mm</option><option>cm</option><option>m</option></select></div></div>`;
    if(mode==='circular') fields=`<div class="form-grid"><div class="form-group"><label>Diameter</label><input class="input" type="number" data-size-field="diameter" value="315"></div><div class="form-group"><label>Unit</label><select class="select" data-size-field="unit"><option>mm</option><option>cm</option><option>m</option></select></div></div>`;
    if(mode==='linear') fields=`<div class="form-grid"><div class="form-group"><label>Length</label><input class="input" type="number" data-size-field="length" value="6"></div><div class="form-group"><label>Unit</label><select class="select" data-size-field="unit"><option>m</option><option>mm</option><option>cm</option></select></div></div>`;
    if(mode==='pipe') fields=`<div class="form-grid"><div class="form-group"><label>Nominal Size</label><input class="input" data-size-field="pipe" value="DN50"></div><div class="form-group"><label>Display standard</label><select class="select" data-size-field="pipeType"><option>DN</option><option>Inch</option><option>Custom</option></select></div></div>`;
    if(mode==='custom') fields=`<div class="form-group"><label>Custom size / specification</label><input class="input" data-size-field="custom" value="${esc(row.size||'')}" placeholder="e.g. 0.8 mm x 1.22 m x 2.44 m"></div>`;
    const body=`<div class="size-tabs">${[['rectangular','Rectangular'],['circular','Circular'],['linear','Linear'],['pipe','Pipe / Nominal'],['custom','Custom']].map(([id,label])=>`<button class="size-tab ${mode===id?'active':''}" data-size-mode="${id}">${esc(label)}</button>`).join('')}</div>${fields}<div class="size-preview"><span>Formatted value</span><strong data-size-preview>${esc(row.size||'500 x 500 mm')}</strong></div>`;
    showModal({title:'Build material size',description:'Capture common HVAC sizes quickly while keeping one clean Size column.',body,foot:`<button class="btn" data-action="close-modal">Cancel</button><button class="btn primary" data-action="apply-size" data-scope="${target.scope}" data-row="${target.rowId}">Apply size</button>`,size:'sm'});
    updateSizePreview();
  }
  function sizeValue(){
    const mode=state.ui.sizeMode;
    const get=name=>document.querySelector(`[data-size-field="${name}"]`)?.value?.trim()||'';
    if(mode==='rectangular') return `${get('width')||0} x ${get('height')||0} ${get('unit')||'mm'}`;
    if(mode==='circular') return `Ø${get('diameter')||0} ${get('unit')||'mm'}`;
    if(mode==='linear') return `${get('length')||0} ${get('unit')||'m'}`;
    if(mode==='pipe') return get('pipe')||'DN50';
    return get('custom')||'Custom';
  }
  function updateSizePreview(){ const el=document.querySelector('[data-size-preview]'); if(el) el.textContent=sizeValue(); }
  function openRowMenu(scope,rowId){
    const row=rowFromScope(scope,rowId);
    showModal({title:'Row actions',description:row?.description||'Material row',body:`<div class="list"><button class="nav-item" data-action="duplicate-row" data-scope="${scope}" data-row="${rowId}">${icon('copy')} Duplicate as similar row</button><button class="nav-item" data-action="clear-row" data-scope="${scope}" data-row="${rowId}">${icon('refresh')} Clear row values</button><button class="nav-item" data-action="delete-row" data-scope="${scope}" data-row="${rowId}" style="color:var(--red)">${icon('x')} Delete row</button></div>`,foot:`<button class="btn" data-action="close-modal">Close</button>`,size:'sm'});
  }
  function openCostSettings(){
    const rows=['Engineer','Procurement','Admin'].map(role=>`<div class="fact-row"><span>${esc(role)}</span><label class="toggle"><button class="${state.settings.costVisibility[role]?'on':''}" data-action="toggle-cost-role" data-role="${role}"></button><strong>${state.settings.costVisibility[role]?'Visible':'Hidden'}</strong></label></div>`).join('');
    showModal({title:'Commercial cost visibility',description:'Admin controls which roles can receive Unit Cost and Total Cost data.',body:`<div class="notice amber"><div class="notice-icon">${icon('lock')}</div><div><strong>Backend enforcement required</strong><p>Hidden cost fields should not be sent to unauthorised devices or included in their CSV exports.</p></div></div><div class="fact-list" style="margin-top:14px">${rows}</div>`,foot:`<button class="btn primary" data-action="close-modal">Done</button>`,size:'sm'});
  }
  function openReceiptModal(poId){
    const po=poById(poId); if(!po) return;
    const lines=po.items.filter(item=>item.received<item.ordered);
    const body=lines.length?`<div class="form-grid">${lines.map((item,i)=>`<div class="form-group full"><label>${esc(item.description)} · ${esc(item.modelSerial)}</label><div class="grid three"><div class="form-group"><span class="hint">Remaining</span><input class="input" value="${item.ordered-item.received}" disabled></div><div class="form-group"><span class="hint">Receive now</span><input class="input" type="number" min="0" max="${item.ordered-item.received}" value="${item.ordered-item.received}" data-receive-line="${i}" data-row="${item.rowId}"></div><div class="form-group"><span class="hint">Condition</span><select class="select" data-receive-condition="${item.rowId}"><option>Good</option><option>Damaged</option><option>Rejected</option></select></div></div></div>`).join('')}<div class="form-group full"><label>Supplier Delivery Note</label><input class="input" value="DN-" data-receive-note></div><div class="form-group full"><label>Receipt notes</label><textarea class="textarea" data-receive-notes placeholder="Condition, shortage or site notes"></textarea></div></div><div class="upload-zone" style="margin-top:14px">${icon('camera')}<strong>Attach delivery slip photograph</strong><span>Camera or file upload in the production app</span></div>`:`<div class="empty-state"><div class="empty-icon">${icon('check')}</div><h3>Order fully received</h3><p>No remaining quantity is open on this purchase order.</p></div>`;
    showModal({title:`Record receipt · ${po.id}`,description:'Receive the actual quantity delivered and preserve any shortfall.',body,foot:lines.length?`<button class="btn" data-action="close-modal">Cancel</button><button class="btn primary" data-action="confirm-receipt" data-po="${po.id}">${icon('check')} Save receipt</button>`:`<button class="btn primary" data-action="close-modal">Done</button>`,size:'sm'});
  }
  function openCommand(){
    state.ui.commandOpen=true;
    portal.innerHTML=`<div class="modal-backdrop" data-modal-backdrop><div class="modal command-modal"><input class="command-input" data-command-input placeholder="Search projects, requests, orders or actions…"><div class="command-results">${commandResults('')}</div></div></div>`;
    setTimeout(()=>document.querySelector('[data-command-input]')?.focus(),20);
  }
  function commandResults(query){
    const q=query.toLowerCase().trim();
    const items=[
      {label:'Create Project',detail:'Start the five-step project setup',route:'projects/new',icon:'plus',key:'P'},
      {label:'New Material Request',detail:'Create a fast site request',route:'requests/new',icon:'request',key:'N'},
      ...state.projects.map(project=>({label:project.name,detail:`${project.ref} · Project workspace`,route:`project/${project.id}/overview`,icon:'folder'})),
      ...state.requests.map(request=>({label:request.id,detail:`${request.projectName} · ${request.buildingCode}`,route:`request/${request.id}`,icon:'request'})),
      ...state.purchaseOrders.map(po=>({label:po.id,detail:`${po.supplier} · ${po.status}`,route:`po/${po.id}`,icon:'order'})),
    ].filter(item=>!q||[item.label,item.detail].some(v=>v.toLowerCase().includes(q)));
    return items.slice(0,12).map(item=>`<button class="command-item" data-route="${item.route}"><div class="cmd-icon">${icon(item.icon)}</div><div><strong>${esc(item.label)}</strong><span>${esc(item.detail)}</span></div>${item.key?`<kbd>${item.key}</kbd>`:''}</button>`).join('')||'<div class="empty-state"><h3>No results</h3><p>Try a project reference, request ID, PO number or action.</p></div>';
  }

  function render(){
    const parts=route();
    const first=parts[0]||'home';
    let html='';
    if(first==='home') html=homePage();
    else if(first==='browse') html=browsePage();
    else if(first==='projects'&&parts[1]==='new') html=projectWizardPage();
    else if(first==='projects') html=projectsPage();
    else if(first==='project'){
      const project=projectById(parts[1])||state.projects[0];
      const tab=parts[2]||'overview';
      state.ui.projectId=project.id; state.ui.projectTab=tab;
      if(tab==='overview') html=projectOverview(project);
      else if(tab==='plan') html=projectPlanPage(project);
      else if(tab==='requests') html=projectRequestsPage(project);
      else if(tab==='procurement') html=projectProcurementPage(project);
      else if(tab==='documents') html=projectDocumentsPage(project);
      else html=projectActivityPage(project);
    }
    else if(first==='requests'&&parts[1]==='new') html=newRequestPage();
    else if(first==='requests') html=requestsPage();
    else if(first==='request') html=requestDetailPage(requestById(parts[1])||state.requests[0]);
    else if(first==='procurement'&&parts[1]) html=procurementRequestPage(requestById(parts[1])||state.requests[0]);
    else if(first==='procurement') html=procurementQueuePage();
    else if(first==='orders') html=ordersPage();
    else if(first==='deliveries') html=deliveriesPage();
    else if(first==='po') html=purchaseOrderPage(poById(parts[1])||state.purchaseOrders[0]);
    else html=homePage();
    root.innerHTML=html;
    closeSidebar();
  }
  function closeSidebar(){ document.getElementById('sidebar')?.classList.remove('open'); }
  function rowsForScope(scope){
    if(scope==='new-request') return state.ui.newRequest.rows;
    if(scope==='plan') return projectById(state.ui.projectId||'nexus')?.plan.rows||[];
    return [];
  }
  function updateRow(scope,rowId,field,value){
    const row=rowsForScope(scope).find(item=>item.id===rowId); if(!row) return;
    row[field]=['qty','unitCost'].includes(field)?Number(value||0):value;
    if(scope==='plan') state.ui.selectedPlanRowId=rowId;
    saveState();
  }
  function addBlankRow(scope,seed={}){
    const rows=rowsForScope(scope);
    const row=canonicalRow(seed);
    rows.push(row);
    if(scope==='plan') state.ui.selectedPlanRowId=row.id;
    saveState(); render();
  }
  function addSimilarRow(scope,rowId=''){
    const rows=rowsForScope(scope);
    const source=rows.find(r=>r.id===rowId)||(scope==='plan'?rows.find(r=>r.id===state.ui.selectedPlanRowId):rows.at(-1));
    if(!source){addBlankRow(scope);return;}
    const copied={};
    state.settings.smartCarry.forEach(field=>copied[field]=source[field]);
    copied.modelSerial='';copied.qty=1;copied.unitCost=0;copied.status='draft';copied.source=source.source;
    addBlankRow(scope,copied);
  }
  function deleteRow(scope,rowId){
    const rows=rowsForScope(scope); const index=rows.findIndex(r=>r.id===rowId); if(index>=0) rows.splice(index,1);
    closeModal(); saveState(); render(); toast('Row deleted','The material row was removed from the draft.','x');
  }
  function clearRow(scope,rowId){
    const row=rowsForScope(scope).find(r=>r.id===rowId); if(!row)return;
    Object.assign(row,{description:'',size:'',modelSerial:'',makeOrigin:'',qty:1,unit:'Nos',remarks:'',unitCost:0,status:'draft',source:'custom'});
    closeModal(); saveState(); render();
  }
  function duplicateRow(scope,rowId){ closeModal(); addSimilarRow(scope,rowId); }
  function addMaterialsToTarget(target,selectedIds){
    const rows=target==='plan'?rowsForScope('plan'):state.ui.newRequest.rows;
    selectedIds.forEach(id=>{const m=materials.find(item=>item.id===id);if(!m)return;rows.push(canonicalRow({description:m.description,size:m.size,modelSerial:m.model,makeOrigin:m.makeOrigin,qty:1,unit:m.unit,remarks:'',unitCost:m.unitCost,status:'draft',source:'inventory'}));});
    saveState(); closeModal(); render(); toast('Materials added',`${selectedIds.length} material${selectedIds.length===1?'':'s'} added as clean rows.`,'check');
  }
  function exportCSV(filename,rows){
    const costs=canSeeCosts();
    const headers=['S:No','Item Description','Size (If any)','Model/Serial No.','Make/Origin','QTY','Unit','Remarks',...(costs?['Unit Cost','Total Cost']:[])];
    const values=rows.map((row,index)=>[index+1,row.description,row.size,row.modelSerial,row.makeOrigin,row.qty,row.unit,row.remarks,...(costs?[row.unitCost,row.qty*row.unitCost]:[])]);
    const csv=[headers,...values].map(line=>line.map(value=>`"${String(value??'').replace(/"/g,'""')}"`).join(',')).join('\n');
    const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url;a.download=filename;a.click();URL.revokeObjectURL(url);
    toast('CSV exported',costs?'Commercial fields included for this authorised user.':'Cost columns were excluded by role policy.','download');
  }
  function submitNewRequest(){
    const draft=state.ui.newRequest;
    if(!draft.projectId||!draft.buildingId){toast('Select project and building','Both are required before submission.','alert');return;}
    if(!draft.rows.length||draft.rows.some(row=>!row.description||Number(row.qty)<=0)){toast('Check material rows','Every line needs a description and quantity greater than zero.','alert');return;}
    const project=projectById(draft.projectId),building=project.buildings.find(b=>b.id===draft.buildingId);
    const id=`MR-2026-${String(25+state.requests.length).padStart(3,'0')}`;
    state.requests.unshift({id,projectId:project.id,projectName:project.name,buildingId:building.id,buildingCode:building.code,requestedBy:currentUser().name,requestedAt:nowText(),requiredDate:draft.requiredDate||'Not specified',priority:draft.priority,status:'submitted',currentOwner:'Procurement Queue',notes:draft.notes,rows:clone(draft.rows),fulfilment:Object.fromEntries(draft.rows.map(row=>[row.id,{requested:Number(row.qty),warehouse:0,external:Number(row.qty),ordered:0,received:0}])),linked:{rfqs:[],pos:[],receipts:[]},comments:[],activity:[{actor:currentUser().name,action:'Submitted material request',detail:`${draft.rows.length} lines · ${building.code}`,time:nowText()}]});
    state.ui.newRequest={projectId:project.id,buildingId:building.id,priority:'Normal',requiredDate:'',notes:'',rows:[]};
    saveState(); go(`request/${id}`); toast('Request submitted',`${id} is now visible in the Procurement queue.`,'check');
  }
  function createProject(){
    const draft=state.ui.wizardDraft;
    if(!draft.name||!draft.ref||!draft.client||!draft.buildings.some(b=>b.code&&b.name)){toast('Complete required information','Project reference, name, client and at least one building are required.','alert');return;}
    const id=draft.name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||uid('project');
    const project={id,ref:draft.ref,name:draft.name,client:draft.client,contractNo:draft.contractNo,location:draft.location,consultant:draft.consultant,mainContractor:draft.mainContractor,subcontractors:draft.subcontractors.filter(Boolean),otherContractors:draft.otherContractors.filter(Boolean),startDate:draft.startDate,endDate:draft.endDate,status:'draft',phase:'Planning',createdBy:currentUser().name,createdAt:nowText(),assignedEngineer:draft.assignedEngineer,approver:draft.approver,procurementOwner:'Ali Raza',buildings:draft.buildings.map(b=>({...b,progress:0})),completion:{design:0,supply:0,installation:0,commissioning:0,energizing:0},plan:{status:'draft',version:1,buildingId:draft.buildings[0].id,submittedBy:'',processedBy:'',approvedBy:'',approvedAt:'',rows:[]},activity:[{id:uid('activity'),actor:currentUser().name,role:currentUser().role,action:'Created project draft',detail:`${draft.buildings.length} building${draft.buildings.length===1?'':'s'} added.`,time:nowText()}],documents:draft.attachments};
    state.projects.unshift(project);state.ui.wizardDraft=null;state.ui.wizardStep=1;saveState();go(`project/${id}/plan`);toast('Project draft created','Add the Phase 1 material plan, then submit it to Procurement.','check');
  }
  function confirmReceipt(poId){
    const po=poById(poId); if(!po)return;
    $$('[data-receive-line]').forEach(input=>{const item=po.items.find(i=>i.rowId===input.dataset.row);if(!item)return;const qty=Math.max(0,Math.min(Number(input.value||0),item.ordered-item.received));item.received+=qty;});
    const all=po.items.every(item=>item.received>=item.ordered);po.status=all?'Received':'Partially received';po.history.push({actor:currentUser().name,action:'Recorded delivery receipt',detail:all?'Order fully received':'Partial quantity received; remaining quantity stays open',time:nowText()});
    const request=requestById(po.requestId);po.items.forEach(item=>{if(request?.fulfilment[item.rowId])request.fulfilment[item.rowId].received=item.received;});
    if(request){const done=request.rows.every(row=>(request.fulfilment[row.id]?.received||0)>=(request.fulfilment[row.id]?.requested||row.qty));request.status=done?'received':'sourcing';request.currentOwner=done?'Completed':'Ali Raza';}
    saveState();closeModal();render();toast('Receipt recorded',all?'The purchase order is fully received.':'The partial receipt is saved and the balance remains open.','check');
  }

  document.addEventListener('click',event=>{
    if(event.target.matches('[data-modal-backdrop]')){closeModal();return;}
    const routeEl=event.target.closest('[data-route]');
    if(routeEl){event.preventDefault();go(routeEl.dataset.route);return;}
    const target=event.target.closest('[data-action]');
    if(!target) return;
    const action=target.dataset.action;
    if(action==='toggle-sidebar'){document.getElementById('sidebar')?.classList.toggle('open');return;}
    if(action==='reset'){resetState();return;}
    if(action==='command'){openCommand();return;}
    if(action==='close-modal'){closeModal();return;}
    if(action==='cost-settings'){openCostSettings();return;}
    if(action==='toggle-cost-role'){const role=target.dataset.role;state.settings.costVisibility[role]=!state.settings.costVisibility[role];saveState();openCostSettings();return;}
    if(action==='open-picker'){openPicker(target.dataset.target==='request'?'new-request':target.dataset.target||'new-request');return;}
    if(action==='confirm-picker'){addMaterialsToTarget(state.ui.pickerTarget,state.ui.pickerSelected);return;}
    if(action==='add-custom-from-picker'){const targetScope=state.ui.pickerTarget;closeModal();addBlankRow(targetScope==='plan'?'plan':'new-request');toast('Custom row added','Enter the required material using the approved columns.','plus');return;}
    if(action==='quick-add-material'){const m=materials.find(item=>item.id===target.dataset.material);if(!m)return;state.ui.newRequest.rows.push(canonicalRow({description:m.description,size:m.size,modelSerial:m.model,makeOrigin:m.makeOrigin,qty:1,unit:m.unit,remarks:'',unitCost:m.unitCost,status:'draft',source:'inventory'}));saveState();toast('Added to request',`${m.description} was added to the current draft.`,'plus');return;}
    if(action==='add-blank-row'){addBlankRow(target.dataset.scope);return;}
    if(action==='add-similar-row'){addSimilarRow(target.dataset.scope);return;}
    if(action==='size-builder'){openSizeBuilder(target.dataset.scope,target.dataset.row);return;}
    if(action==='apply-size'){const scope=target.dataset.scope||state.ui.sizeTarget?.scope;const rowId=target.dataset.row||state.ui.sizeTarget?.rowId;const value=sizeValue();const row=rowFromScope(scope,rowId);if(row)row.size=value;saveState();closeModal();render();toast('Size applied',row?.size||'Size updated','check');return;}
    if(action==='row-menu'){openRowMenu(target.dataset.scope,target.dataset.row);return;}
    if(action==='duplicate-row'){duplicateRow(target.dataset.scope,target.dataset.row);return;}
    if(action==='clear-row'){clearRow(target.dataset.scope,target.dataset.row);return;}
    if(action==='delete-row'){deleteRow(target.dataset.scope,target.dataset.row);return;}
    if(action==='export-grid'){const scope=target.dataset.scope;exportCSV(`${scope==='plan'?projectById(state.ui.projectId).ref:'material-request'}-materials.csv`,rowsForScope(scope));return;}
    if(action==='export-browse'){exportCSV('yorks-material-catalogue.csv',filteredMaterials().map(m=>canonicalRow({description:m.description,size:m.size,modelSerial:m.model,makeOrigin:m.makeOrigin,qty:m.stock,unit:m.unit,remarks:`${m.categoryName} · Store ${m.store}`,unitCost:m.unitCost})));return;}
    if(action==='export-project'){const project=projectById(target.dataset.project);exportCSV(`${project.ref}-material-plan.csv`,project.plan.rows);return;}
    if(action==='save-request-draft'){saveState();toast('Draft saved','Continue from any device after the production sync is connected.','check');return;}
    if(action==='review-request'){toast('Ready for review',`${state.ui.newRequest.rows.length} material line${state.ui.newRequest.rows.length===1?'':'s'} will be sent to Procurement.`,'eye');return;}
    if(action==='submit-new-request'){submitNewRequest();return;}
    if(action==='auto-allocate'){toast('Inventory checked','Available stock has been allocated; remaining quantities stay marked for supplier sourcing.','refresh');return;}
    if(action==='allocate-stock'||action==='allocate-vendor'){toast('Allocation opened','In production this opens a compact quantity split control for warehouse and supplier sources.','edit');return;}
    if(action==='create-rfq'){toast('RFQ created','The selected request lines were linked to a new RFQ without re-entry.','quote');return;}
    if(action==='create-pos'){state.ui.procurementTab='orders';saveState();render();toast('Purchase orders ready','Selected supplier lines were converted into linked purchase orders.','order');return;}
    if(action==='receive-po'){openReceiptModal(target.dataset.po);return;}
    if(action==='confirm-receipt'){confirmReceipt(target.dataset.po);return;}
    if(action==='create-plan-revision'){
      const project=projectById(target.dataset.project);if(project.plan.status!=='approved')return;project.plan.baselineVersion=project.plan.version;project.plan.version+=1;project.plan.status='draft';project.plan.rows=project.plan.rows.map(row=>({...row,status:'draft'}));project.activity.push({actor:currentUser().name,action:`Started material plan revision v${project.plan.version}`,detail:`Approved v${project.plan.baselineVersion} remains the active execution baseline`,time:nowText()});saveState();render();toast('Revision started',`v${project.plan.version} is editable; v${project.plan.baselineVersion} remains approved until the new cycle completes.`,'copy');return;
    }
    if(action==='submit-plan'){
      const project=projectById(target.dataset.project);if(!project.plan.rows.length){toast('Add materials first','A Phase 1 plan cannot be submitted with zero lines.','alert');return;}project.plan.status='procurement_review';if(project.phase!=='Execution')project.status='procurement_review';project.plan.submittedBy=currentUser().name;project.activity.push({actor:currentUser().name,action:'Submitted Phase 1 material plan',detail:`${project.plan.rows.length} lines sent to Procurement`,time:nowText()});saveState();render();toast('Plan submitted','Ali Raza was notified and now owns the next action.','check');return;
    }
    if(action==='mark-plan-ready'){
      const project=projectById(target.dataset.project);project.plan.status='ready_for_approval';if(project.phase!=='Execution')project.status='ready_for_approval';project.plan.processedBy=currentUser().name;project.activity.push({actor:currentUser().name,action:'Completed procurement arrangement',detail:'Plan sent to Engineer for final approval',time:nowText()});saveState();render();toast('Sent for approval',`${project.approver} now owns the next action.`,'check');return;
    }
    if(action==='approve-plan'){
      const project=projectById(target.dataset.project);project.plan.status='approved';project.status='active';project.phase='Execution';project.plan.approvedBy=currentUser().name;project.plan.approvedAt=nowText();project.plan.baselineVersion=null;project.activity.push({actor:currentUser().name,action:'Approved Phase 1 material plan',detail:'Project activated and Phase 2 requests opened',time:nowText()});saveState();render();toast('Project activated','The approved plan is now the baseline for execution.','check');return;
    }
    if(action==='add-comment'){toast('Comment added','The comment is attached to the current record and will appear in its history.','comment');return;}
    if(action==='wizard-next'){state.ui.wizardStep=Math.min(5,(state.ui.wizardStep||1)+1);saveState();render();return;}
    if(action==='wizard-back'){state.ui.wizardStep=Math.max(1,(state.ui.wizardStep||1)-1);saveState();render();return;}
    if(action==='save-project-draft'){saveState();toast('Project draft saved','You can return to the same step later.','check');return;}
    if(action==='add-wizard-array'){ensureWizard()[target.dataset.key].push('');saveState();render();return;}
    if(action==='remove-wizard-array'){const arr=ensureWizard()[target.dataset.key];arr.splice(Number(target.dataset.index),1);if(!arr.length)arr.push('');saveState();render();return;}
    if(action==='add-building'){ensureWizard().buildings.push({id:uid('b'),code:'',name:'',floors:'',hasFRP:false});saveState();render();return;}
    if(action==='remove-building'){const buildings=ensureWizard().buildings;if(buildings.length===1){toast('One building required','A project needs at least one building record.','alert');return;}buildings.splice(Number(target.dataset.index),1);saveState();render();return;}
    if(action==='toggle-frp'){const b=ensureWizard().buildings[Number(target.dataset.index)];b.hasFRP=!b.hasFRP;saveState();render();return;}
    if(action==='create-project'){createProject();return;}
    if(action==='upload-document'){const draft=state.ui.wizardDraft;if(draft){draft.attachments.push({id:uid('file'),name:'Project_Drawing_RevA.pdf',type:'Drawing',ref:'DRAFT',revision:'A',uploadedBy:currentUser().name,time:nowText()});saveState();render();}else toast('Upload control','The production build will use camera, drag-and-drop and file selection.','upload');return;}
  });

  document.addEventListener('click',event=>{
    const category=event.target.closest('[data-browse-category]');
    if(category){state.ui.browseCategory=category.dataset.browseCategory;saveState();render();return;}
    const selected=event.target.closest('[data-browse-select]');
    if(selected){state.ui.browseSelectedId=selected.dataset.browseSelect;saveState();render();return;}
    const pcat=event.target.closest('[data-picker-category]');
    if(pcat){state.ui.pickerCategory=pcat.dataset.pickerCategory;renderPicker();return;}
    const pitem=event.target.closest('[data-picker-item]');
    if(pitem){const id=pitem.dataset.pickerItem;state.ui.pickerSelected=state.ui.pickerSelected.includes(id)?state.ui.pickerSelected.filter(x=>x!==id):[...state.ui.pickerSelected,id];renderPicker();return;}
    const sizeMode=event.target.closest('[data-size-mode]');
    if(sizeMode){state.ui.sizeMode=sizeMode.dataset.sizeMode;renderSizeBuilder();return;}
    const procTab=event.target.closest('[data-proc-tab]');
    if(procTab){state.ui.procurementTab=procTab.dataset.procTab;saveState();render();return;}
    const row=event.target.closest('[data-select-row]');
    if(row&&row.dataset.scope==='plan'){state.ui.selectedPlanRowId=row.dataset.selectRow;saveState();render();return;}
  });

  document.addEventListener('input',event=>{
    if(event.target.matches('[data-browse-search]')){state.ui.browseSearch=event.target.value;saveState();render();setTimeout(()=>document.querySelector('[data-browse-search]')?.focus(),0);return;}
    if(event.target.matches('[data-picker-search]')){state.ui.pickerSearch=event.target.value;renderPicker();setTimeout(()=>{const input=document.querySelector('[data-picker-search]');if(input){input.focus();input.setSelectionRange(input.value.length,input.value.length);}},0);return;}
    if(event.target.matches('[data-size-field]')){updateSizePreview();return;}
    if(event.target.matches('[data-grid-cell]')){updateRow(event.target.dataset.scope,event.target.dataset.row,event.target.dataset.field,event.target.value);return;}
    if(event.target.matches('[data-new-request-field]')){state.ui.newRequest[event.target.dataset.newRequestField]=event.target.value;if(event.target.dataset.newRequestField==='projectId'){const p=projectById(event.target.value);state.ui.newRequest.buildingId=p?.buildings[0]?.id||'';}saveState();return;}
    if(event.target.matches('[data-wizard-field]')){ensureWizard()[event.target.dataset.wizardField]=event.target.value;saveState();return;}
    if(event.target.matches('[data-wizard-array]')){ensureWizard()[event.target.dataset.wizardArray][Number(event.target.dataset.index)]=event.target.value;saveState();return;}
    if(event.target.matches('[data-building-field]')){ensureWizard().buildings[Number(event.target.dataset.index)][event.target.dataset.buildingField]=event.target.value;saveState();return;}
    if(event.target.matches('[data-command-input]')){document.querySelector('.command-results').innerHTML=commandResults(event.target.value);return;}
  });

  document.addEventListener('change',event=>{
    if(event.target.matches('[data-action="switch-user"]')){state.currentUserId=event.target.value;saveState();render();toast('View changed',`You are now viewing the workflow as ${currentUser().name}.`,'users');return;}
    if(event.target.matches('[data-grid-cell][data-field="unit"]')){
      if(event.target.value==='__custom__'){
        const value=prompt('Enter custom unit');
        if(value){const unit=value.trim();if(unit&&!state.settings.customUnits.includes(unit))state.settings.customUnits.push(unit);event.target.value=unit;updateRow(event.target.dataset.scope,event.target.dataset.row,'unit',unit);render();}
        else render();
      }else updateRow(event.target.dataset.scope,event.target.dataset.row,'unit',event.target.value);
      return;
    }
    if(event.target.matches('[data-new-request-field]')){state.ui.newRequest[event.target.dataset.newRequestField]=event.target.value;if(event.target.dataset.newRequestField==='projectId'){const p=projectById(event.target.value);state.ui.newRequest.buildingId=p?.buildings[0]?.id||'';}saveState();render();return;}
    if(event.target.matches('[data-wizard-field]')){ensureWizard()[event.target.dataset.wizardField]=event.target.value;saveState();return;}
    if(event.target.matches('[data-select-quote]')){state.rfq.selected[event.target.dataset.row]=event.target.value;saveState();render();return;}
    if(event.target.matches('[data-action="plan-building"]')){projectById(state.ui.projectId).plan.buildingId=event.target.value;saveState();render();return;}
  });

  window.addEventListener('hashchange',()=>{closeModal();render();});
  document.addEventListener('keydown',event=>{
    if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'){event.preventDefault();openCommand();return;}
    if(event.key==='Escape'){closeModal();closeSidebar();return;}
    if(!['INPUT','TEXTAREA','SELECT'].includes(document.activeElement?.tagName)){
      if(event.key.toLowerCase()==='n'){go('requests/new');}
      if(event.key.toLowerCase()==='p'){go('projects/new');}
    }
  });

  loadState();
  render();
})();
