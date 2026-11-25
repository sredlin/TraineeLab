# Texts around client projects (see README.md)
@{
    RequestNote = @(
        @{ Voice = 'OBennett'; Text = 'Call w/ {Ansprechpartner} ({KundeKurz}), {Datum}:
- want {Projekt}, ideally kick off {Termin2}
- budget "somewhere around" {Budget}, final tbc
- channels: {Kanal} + {Kanal2}, print = nice to have
- quote asap, {Termin} latest. FYI {KollegeVorname}' }
        @{ Voice = 'FBloggs'; Text = 'Enquiry from {Kunde} dated {Datum}. Project: {Projekt}. Client budget {Budget}, estimated effort {Stunden} hours. Last invoice paid only after a reminder, hence 30 per cent on order. Submit quote for approval by {Termin}.' }
        @{ Voice = 'JBloggs'; Text = 'Hi everyone, {Ansprechpartner} just rang – {KundeKurz} want to do {Projekt} with us! She was still raving about our meeting on {Vortermin}. I''d love to have {KollegeVorname} on board. Who has room this week? The quote has to go out by {Termin}!' }
        @{ Voice = 'CWhitfield'; Text = 'Email from {Ansprechpartner}: {Projekt}, preferred date {Termin2}. Doable if we use existing photos and skip our own shoot. I''ve hinted as much. I''ll write the quote; {KollegeVorname}, please estimate design time by tomorrow.' }
        @{ Voice = 'SPatel'; Text = 'Just had {Ansprechpartner} on the phone :-) They want {Projekt}, but not till after the summer. She didn''t know the budget. Said we''d get back to them by {Termin}. Can someone who''s costed this sort of thing take it?' }
        @{ Voice = 'DPrice'; Text = 'Sorry if someone already knows this: {Ansprechpartner} from {KundeKurz} rang on {Datum} about {Projekt}. I said someone would get back to them. Was that right? Best to call back in the morning. Should I set up a project folder already?' }
        @{ Text = 'Phone note {Datum}: {Ansprechpartner} ({Kunde}) asking about {Projekt}. Like what we showed on {Vortermin}, only smaller. Run of approx. {Auflage}, delivery by {Termin2} at the latest. Open: who writes the copy? Promised a call back by {Termin}.' }
        @{ Text = 'Email enquiry from {Ansprechpartner}: {Projekt} via {Kanal}. They''re also asking two other agencies, so price matters. Suggestion: basic package without a shoot for approx. {Betrag}, shoot as an option. {Leitung} to decide.' }
    )
    OfferIntro = @(
        @{ Text = 'Thank you for the meeting on {Vortermin}. As discussed, please find our quote for {Projekt} below. We have split it into two parts: concept and design at a fixed price, printing and media booking at cost.' }
        @{ Text = 'We are happy to quote for {Projekt}. It is based on your email of {Vortermin} and our previous projects for {KundeKurz}. Where details were missing, we have made assumptions and marked them as such.' }
        @{ Text = 'After our meeting with you in {Stadt}, we have sorted through the ideas and done the sums. Your budget of {Budget} covers everything you mentioned, with one exception: we have listed the photo shoot as an option.' }
        @{ Text = 'Please find attached our revised quote for {Projekt}. It replaces the version of {Vortermin}: as discussed, we have increased the print run to {Auflage} copies and added a second round of corrections.' }
    )
    OfferClose = @(
        @{ Text = 'This quote is valid until {Termin}. To keep to the start date of {Termin2}, we would need your go-ahead at least one week beforehand.' }
        @{ Text = 'If any items seem too high, please let us know. The print run or number of designs can usually be adjusted without the result suffering.
We look forward to working with you.' }
        @{ Text = 'All prices are exclusive of VAT. Third-party costs such as printing and image licences are passed on without mark-up, with receipts enclosed. This quote is valid for 30 days.' }
        @{ Text = 'Once you confirm the order, we will send a schedule and a list of what we need from you. Things move fastest if your logo, copy and images reach us by {Termin}.' }
    )
    BriefingBackground = @(
        @{ Industry = 'Retail'; Text = 'The shop lives on passing trade. Since the street was redesigned, fewer people walk past. The range of {Produkt} has grown, but hardly anyone knows about it.' }
        @{ Industry = 'Hospitality'; Text = 'Packed at lunchtime, empty tables in the evening. The new seasonal menu starts in {Monat}; the delivery service has run for a year, but few know it.' }
        @{ Industry = 'Hotel'; Text = 'In summer the hotel is fully booked; from November to March occupancy is around {Prozent}%. The aim is for {Produkt} to fill the low season.' }
        @{ Industry = 'Crafts'; Text = 'Plenty of work; the problem is people. Two skilled staff are retiring, and the last job advert drew three applications. Work is already being turned down.' }
        @{ Industry = 'Health'; Text = 'More patients should use {Produkt}. Advertising is tightly regulated: the CAP Code bans promises of a cure, and before-and-after comparisons are off limits too.' }
        @{ Industry = 'Education'; Text = 'Enrolment numbers for {Jahr} are down. Parents now research almost entirely online, and the five-year-old brochure shows rooms that no longer look like that.' }
        @{ Industry = 'Leisure'; Text = 'From October to March the classes are full; in summer demand drops by a third. There are summer classes, but hardly anyone knows.' }
        @{ Industry = 'RealEstate'; Text = 'A third of the development has been sold. Viewings are well attended, but too few reservations follow. The particulars are text-heavy and come without floor plans.' }
        @{ Industry = 'Energy'; Text = 'After recent price hikes many households are unsettled; some have switched supplier twice already. {KundeKurz} wants to win on trust, not on the cheapest tariff.' }
        @{ Industry = 'IT'; Text = '{KundeKurz} sells {Produkt} to mid-sized businesses; new clients come almost solely via referrals. Plus four vacancies: skilled staff are harder to find than customers.' }
        @{ Industry = 'Club'; Text = 'Around 300 members, and the average age is rising. Without new volunteers the youth sessions stop from next season, and the committee has been looking for a treasurer for a year.' }
        @{ Industry = 'Culture'; Text = 'The new season opens in {Monat}. Advance booking was sluggish last year, season tickets have been falling for three years, and single tickets are bought later and later.' }
        @{ Text = '{KundeKurz} has been known in {Stadt} for years, but for its old range. {Produkt} needs to come to the fore without putting off regulars.' }
        @{ Text = 'The last campaign ({Vortermin}) brought reach but hardly any enquiries. This time results must be measurable: own landing page, own code on every flyer.' }
    )
    BriefingAudience = @(
        @{ Industry = 'Retail'; Text = 'Neighbourhood customers on foot or by bike. They want to handle things and get advice; they compare prices online but like to buy locally.' }
        @{ Industry = 'Hospitality'; Text = 'Office workers from around the area with half an hour for lunch. At weekends, families and couples who have time and like trying new things.' }
        @{ Industry = 'Hotel'; Text = 'Couples aged 35 to 60 within two hours'' drive who book one or two nights at short notice. They want peace and quiet, a good breakfast and no bustle.' }
        @{ Industry = 'Crafts'; Text = 'Two groups: qualified tradespeople who would move if pay and atmosphere were right, and school leavers looking for an apprenticeship. For the younger ones, parents read along.' }
        @{ Industry = 'Health'; Text = 'Adults over 40 who so far only come when something is wrong. They are sceptical of advertising and want facts rather than promises.' }
        @{ Industry = 'Education'; Text = 'Parents looking for something for their children, and adults learning alongside work. Time of day, travel and price decide. Enrolment is online.' }
        @{ Industry = 'Leisure'; Text = 'Beginners aged 20 to 45 who want to try something new but are afraid of making fools of themselves. The trial session is the real hurdle.' }
        @{ Industry = 'RealEstate'; Text = 'Couples and small families on good incomes, searching for months. They know prices, read particulars closely and bring a list of questions to viewings.' }
        @{ Industry = 'Energy'; Text = 'Households wary of switching because they have been caught out before. A local contact matters more to them than a penny per kilowatt hour.' }
        @{ Industry = 'IT'; Text = 'Managing directors and IT managers at firms with 20 to 200 staff: little time, plenty of scepticism. Plus skilled professionals thinking about a move.' }
        @{ Industry = 'Club'; Text = 'Members who should get more involved again, and families from the neighbourhood who only know the club from walking past.' }
        @{ Industry = 'Culture'; Text = 'Regulars over 50 who buy season tickets, and younger people who come on a whim if they hear in time. The second group is harder to reach.' }
        @{ Text = 'The focus is on {Zielgruppe}. Alongside them, existing customers who know {KundeKurz} but have never tried {Produkt}.' }
        @{ Text = 'Primarily {Zielgruppe} within 10 miles of {Stadt}. Not the focus: bargain hunters who only come for the discount and never return.' }
    )
    ConceptSituation = @(
        @{ Industry = 'Retail'; Text = 'Good location, but the shop window looks random. Passers-by walk on because from outside you can''t tell what''s inside.' }
        @{ Industry = 'Hospitality'; Text = 'The lunch menu carries the business. Mainly regulars know the seasonal menu and delivery service.' }
        @{ Industry = 'Hotel'; Text = 'Full in summer, half empty in winter. The low season was only ever sold on discounts, which drags prices down.' }
        @{ Industry = 'Crafts'; Text = 'Full order books, too few staff. The job adverts look like every other firm''s.' }
        @{ Industry = 'Health'; Text = 'Good word of mouth, barely visible online. The ads must work without promising cures.' }
        @{ Industry = 'Education'; Text = 'Enrolment runs through a PDF form that defeats many parents. The website is barely readable on a phone.' }
        @{ Industry = 'Leisure'; Text = 'Strong winter season, weak summer. The classes are good, but newcomers don''t dare to come in.' }
        @{ Industry = 'RealEstate'; Text = 'Lots of viewings, few sales. Buyers compare five properties, and our particulars don''t stick.' }
        @{ Industry = 'Energy'; Text = 'The market is full of teaser deals. {KundeKurz} isn''t the cheapest, but it is local and easy to reach.' }
        @{ Industry = 'IT'; Text = 'Technically strong, invisible from outside. Neither clients nor applicants know what {KundeKurz} actually does.' }
        @{ Industry = 'Club'; Text = 'A small core has carried everything for years and is getting tired. New members join but stay passive.' }
        @{ Industry = 'Culture'; Text = 'A loyal audience that is getting older. Booking opens late, and many only hear about a show after opening night.' }
        @{ Text = 'Position after the briefing on {Vortermin}: well-known brand, falling demand for {Produkt}, {Budget} for the whole year.' }
        @{ Text = 'Competitors advertise loudly, on price. {KundeKurz} has neither the budget nor the appetite for that, but better stories.' }
    )
    ConceptIdea = @(
        @{ Industry = 'Retail'; Text = 'The shop window becomes a poster: each month one product staged large, the same scene on {Kanal}.' }
        @{ Industry = 'Hospitality'; Text = 'The lunch menu gets a face: the weekly menu as a poster, on {Kanal} every Monday, delivery orders via QR code.' }
        @{ Industry = 'Hotel'; Text = 'The low season as an advantage: empty beach, warm sauna, no crowds. Instead of a discount, a package with dinner.' }
        @{ Industry = 'Crafts'; Text = 'Our own people are the campaign: real tradespeople with name, tools and one line on why they stay.' }
        @{ Industry = 'Health'; Text = 'Information instead of promises: what happens with {Produkt}, how long it takes, what it costs. Factual, friendly, no gimmicks.' }
        @{ Industry = 'Education'; Text = 'An ordinary day, honestly photographed. Plus an enrolment that takes three minutes on a phone.' }
        @{ Industry = 'Leisure'; Text = '“Day one” as the theme: newcomers talk about their first session. Free taster session, summer classes outdoors.' }
        @{ Industry = 'RealEstate'; Text = 'Homes, not square footage: every brochure opens with a morning in the flat; floor plan and figures follow on page two.' }
        @{ Industry = 'Energy'; Text = 'Faces, not tariff tables: customer service staff put their names to the switch. Anyone who calls gets through to them.' }
        @{ Industry = 'IT'; Text = 'Show the clients'' problems, not the technology: the printer on Monday, the backup on Friday. {KundeKurz} sorts it.' }
        @{ Industry = 'Club'; Text = '“A little goes a long way”: one hour a month instead of a committee post. Each task is on a card to pick up at the clubhouse.' }
        @{ Industry = 'Culture'; Text = 'A look behind the scenes: posters show rehearsals and people you never normally see. Booking opening becomes an event in itself.' }
        @{ Text = 'The guiding idea is the claim “{Claim}”. Everything we show has to deliver on that line, or it goes.' }
        @{ Text = 'Fewer channels, done properly: {Kanal} as the lead channel, {Kanal2} in support. Everything else is dropped for this round.' }
    )
    Claim = @(
        @{ Industry = 'Retail'; Text = 'Please do touch.' }
        @{ Industry = 'Retail'; Text = 'Just round the corner.' }
        @{ Industry = 'Hospitality'; Text = 'Your lunchtime local.' }
        @{ Industry = 'Hospitality'; Text = 'In season, on your plate.' }
        @{ Industry = 'Hotel'; Text = 'At last, the off-season.' }
        @{ Industry = 'Hotel'; Text = 'Room to breathe.' }
        @{ Industry = 'Crafts'; Text = 'Many hands wanted.' }
        @{ Industry = 'Crafts'; Text = 'Good work lasts.' }
        @{ Industry = 'Health'; Text = 'Well advised.' }
        @{ Industry = 'Health'; Text = 'In steady hands.' }
        @{ Industry = 'Education'; Text = 'Sign up. Settle in.' }
        @{ Industry = 'Education'; Text = 'Where learning is a pleasure.' }
        @{ Industry = 'Leisure'; Text = 'Just give it a go.' }
        @{ Industry = 'Leisure'; Text = 'Make the season yours.' }
        @{ Industry = 'RealEstate'; Text = 'Love it first. Do the maths later.' }
        @{ Industry = 'RealEstate'; Text = 'Well worth a viewing.' }
        @{ Industry = 'Energy'; Text = 'Power from down the road.' }
        @{ Industry = 'Energy'; Text = 'Switch without the stress.' }
        @{ Industry = 'IT'; Text = 'It just works. Even on Mondays.' }
        @{ Industry = 'IT'; Text = 'IT you never notice.' }
        @{ Industry = 'Club'; Text = 'One hour is all it takes.' }
        @{ Industry = 'Club'; Text = 'Join in. Stick around.' }
        @{ Industry = 'Culture'; Text = 'The evening is yours.' }
        @{ Industry = 'Culture'; Text = 'New season. Great seats.' }
        @{ Text = 'Good. And local.' }
        @{ Text = 'Closer to you.' }
    )
    Motif = @(
        @{ Industry = 'Retail'; Text = 'Customer lifts an item off the shelf, the shop assistant laughs and points out a detail' }
        @{ Industry = 'Retail'; Text = 'View from the street into the lit shop window, early evening, passers-by blurred' }
        @{ Industry = 'Hospitality'; Text = 'Dish of the day on a wooden table, the busy lunchtime counter behind' }
        @{ Industry = 'Hospitality'; Text = 'Bicycle courier at the door taking a bag for the delivery service' }
        @{ Industry = 'Hotel'; Text = 'Couple in bathrobes with tea by the window, a grey winter''s day outside' }
        @{ Industry = 'Hotel'; Text = 'Empty beach in the morning mist, two deckchairs, marram grass in the foreground' }
        @{ Industry = 'Crafts'; Text = 'Tradeswoman measuring with a folding rule, pencil behind her ear, workshop behind' }
        @{ Industry = 'Crafts'; Text = 'Team in workwear having breakfast on the back of the company van' }
        @{ Industry = 'Health'; Text = 'Advice at the reception desk, friendly and calm, no treatment scene' }
        @{ Industry = 'Health'; Text = 'Bright waiting area with a plant and a view of greenery, nobody waiting' }
        @{ Industry = 'Education'; Text = 'Adults in a classroom in the evening, one learner laughing at her own notes' }
        @{ Industry = 'Education'; Text = 'Mother enrolling on her phone at the kitchen table, child drawing beside her' }
        @{ Industry = 'Leisure'; Text = 'Beginner in her first session, the instructor demonstrates the posture, both laughing' }
        @{ Industry = 'Leisure'; Text = 'Group outdoors on the grass after the summer class, sweaty and happy' }
        @{ Industry = 'RealEstate'; Text = 'Morning light in the empty kitchen, a coffee cup on the windowsill' }
        @{ Industry = 'RealEstate'; Text = 'Couple holding the brochure at a viewing, she points to the big window' }
        @{ Industry = 'Energy'; Text = 'Customer adviser on the phone, name badge legible, the town in the window' }
        @{ Industry = 'Energy'; Text = 'Family at the kitchen table with the annual statement, relaxed rather than alarmed' }
        @{ Industry = 'IT'; Text = 'Technician swaps a hard drive in the server rack, the client looking over his shoulder' }
        @{ Industry = 'IT'; Text = 'Office on a Monday morning, everyone working, nobody swearing at the printer' }
        @{ Industry = 'Club'; Text = 'Volunteers painting the clubhouse together, a flask of tea on the ladder' }
        @{ Industry = 'Club'; Text = 'Older members showing newcomers the ropes at the start of the season' }
        @{ Industry = 'Culture'; Text = 'Actress at the dressing-room mirror, moments before going on' }
        @{ Industry = 'Culture'; Text = 'Foyer after the show: glasses, conversation, rolled-up programmes' }
        @{ Text = '{Ansprechpartner} outside the entrance in {Stadt}, sleeves rolled up' }
        @{ Text = '{Produkt} on a neutral background, softly lit, plenty of space for text on the right' }
    )
    AdCopy = @(
        @{ Industry = 'Retail'; Text = 'Come in and pick it up. Our range of {Produkt} has grown, and the advice is as thorough as ever.' }
        @{ Industry = 'Hospitality'; Text = 'New seasonal menu from {Termin2}. Lunch Monday to Friday from 11.30am. No time? We deliver across the neighbourhood.' }
        @{ Industry = 'Hotel'; Text = 'Stay three nights, pay for two: midweek from November to March. Sauna, breakfast until 11am and a beach almost to yourself.' }
        @{ Industry = 'Crafts'; Text = 'We''ve got more work than hands. You know your trade and want a firm where people know your name? Give us a ring or pop in.' }
        @{ Industry = 'Health'; Text = 'We take time for your questions about {Produkt}. Early morning and late afternoon appointments too.' }
        @{ Industry = 'Education'; Text = 'The new programme is out. Enrol online now, even from the sofa at night. Enrolment closes on {Termin}.' }
        @{ Industry = 'Leisure'; Text = 'Your first session is free, and no experience is needed. Summer classes start on {Termin2}.' }
        @{ Industry = 'RealEstate'; Text = 'Two bedrooms, south-facing balcony, available {Quartal}. Saturday viewings by appointment; we''ll gladly send the brochure in advance.' }
        @{ Industry = 'Energy'; Text = 'Switching takes ten minutes, and we''ll deal with your old supplier for you. Any questions? We''re right here in {Stadt}.' }
        @{ Industry = 'IT'; Text = 'Your network runs, your data is backed up, and if anything sticks, a real person calls you back. {Produkt} for local businesses.' }
        @{ Industry = 'Club'; Text = 'We''re not looking for committee members, just people with an hour a month. More at our open day on {Termin2}.' }
        @{ Industry = 'Culture'; Text = 'The new season is here. Booking opens {Termin2}; season tickets at last year''s prices until {Termin}.' }
        @{ Industry = 'Retail'; Text = 'New in store: {Produkt}. We tried it ourselves before it went on the shelf. Try it in store, no obligation to buy.' }
        @{ Industry = 'Retail'; Text = 'Open Saturdays until 6pm, parking right outside. Order by Thursday and it''s ready for you on Saturday.' }
        @{ Industry = 'Hospitality'; Text = 'Fresh from the oven from 7am. Pre-order until 6pm the day before, by phone or email.' }
        @{ Industry = 'Hospitality'; Text = 'Celebrate with us: private room for up to 30 guests, menu by arrangement. Ask about available dates in {Monat}.' }
        @{ Industry = 'Hotel'; Text = 'Arrive, drop your bags, head for the water. Sea-view rooms can be booked again from {Termin2}.' }
        @{ Industry = 'Hotel'; Text = 'Conferences for up to 40 people with AV, refreshments and a block of rooms. One contact for everything.' }
        @{ Industry = 'Crafts'; Text = 'Workshop appointments usually within a week. Estimate up front, billed on time spent, no surprises.' }
        @{ Industry = 'Crafts'; Text = 'An apprenticeship with us means being on site from day one. Apply by {Termin}; work experience any time.' }
        @{ Industry = 'Health'; Text = 'New patients are welcome. We offer a first appointment within two weeks, online too.' }
        @{ Industry = 'Health'; Text = 'Step-free access, lift in the building, parking in the courtyard. Please bring your NHS number with you.' }
        @{ Industry = 'Education'; Text = 'Courses in the morning, the evening and at weekends, in groups of no more than twelve.' }
        @{ Industry = 'Education'; Text = 'Concessions for students and pensioners. Many courses count towards CPD – just ask us.' }
        @{ Industry = 'Leisure'; Text = 'Under-sixes go free, brothers and sisters half price. Equipment hire on site.' }
        @{ Industry = 'Leisure'; Text = 'Open in all weathers, indoors and out. Gift vouchers at the till and online.' }
        @{ Industry = 'RealEstate'; Text = 'New build to current efficiency standards, completion in {Quartal}. Four flats still available, floor plans on request.' }
        @{ Industry = 'RealEstate'; Text = 'Thinking of selling? We''ll value your property free of charge and tell you honestly what''s realistic.' }
        @{ Industry = 'Energy'; Text = 'Electricity from the region, price guaranteed for 24 months. Change your Direct Debit online, any time.' }
        @{ Industry = 'Energy'; Text = 'Power cut? Our hotline is staffed round the clock – by people from {Stadt}.' }
        @{ Industry = 'IT'; Text = 'New workstations set up in a day, data transferred, old kit disposed of properly.' }
        @{ Industry = 'IT'; Text = 'Remote support within 30 minutes, on site the same day anywhere in town. Fixed monthly price.' }
        @{ Industry = 'Club'; Text = 'Training Tuesdays and Thursdays from 6pm, taster sessions any time. Membership £7 a month.' }
        @{ Industry = 'Club'; Text = 'Summer fete on {Termin2}: jumble sale, cake stall and a tournament for all ages. Helpers wanted.' }
        @{ Industry = 'Culture'; Text = 'Family performance on Sundays at 3pm. Children £4, adults £10.' }
        @{ Industry = 'Culture'; Text = 'Backstage tours on the first Saturday of every month. Book at the box office.' }
        @{ Text = '{Claim} {Produkt} from {KundeKurz}, in the heart of {Stadt}. The kettle''s on.' }
        @{ Text = 'In {Stadt} for years, and still not everyone knows us. Let''s change that: {Produkt}, honest advice and fair prices.' }
    )
    BriefingGoal = @(
        @{ Text = 'By the end of {Quartal}, enquiries via {Kanal} should be up {Prozent}% on the same period last year. Measured via the contact form and the code on the flyer.' }
        @{ Text = 'Not reach but response: 50 usable enquiries by {Termin2}. Better a few that fit than lots of clicks.' }
        @{ Text = 'People in {Stadt} should know that {KundeKurz} offers {Produkt}. Hard to measure, so a short survey before and after the campaign.' }
    )
    BriefingMandatory = @(
        @{ Text = 'Logo only in the {Jahr} version, house colours as per the style guide. No stock photos with models, only real staff. Company details on every printed item.' }
        @{ Text = 'The client supplies the copy, we edit it. Prices always including VAT. Approvals only via {Ansprechpartner}, not via the branches.' }
        @{ Text = 'Print type at least 10 pt, contrast checked. Get any statements on prices and discounts confirmed in writing before printing.' }
    )
    BriefingTiming = @(
        @{ Text = 'Briefing {Vortermin}, first drafts {Termin}, print files one week before launch, campaign launch {Termin2}. There is no buffer; bank holidays are factored in.' }
        @{ Text = 'Wk 1–2 concept, wk 3 presentation, wk 4–5 development and corrections, wk 6 print. Launch {Termin2}. If approval slips, everything slips.' }
        @{ Text = 'Presentation on {Termin}, then two rounds of corrections of three working days each. Online launch {Termin2}, print follows two weeks later.' }
    )
    ConceptGoals = @(
        @{ Text = '1. {Prozent}% more enquiries by the end of {Quartal}
2. The same visual style across all channels
3. Cost per enquiry below the last campaign''s' }
        @{ Text = 'What counts is response via {Kanal}. Reach on {Kanal2} is welcome but does not count as success.' }
        @{ Text = 'Two goals that clash: more new customers and no discounts. We prioritise new customers and limit discounts to one promotion in {Monat}.' }
    )
    ConceptMeasures = @(
        @{ Text = '• Poster series with three designs
• {Auflage} flyers for the point of sale
• Landing page with sign-up form
• four weeks of ads on {Kanal}' }
        @{ Text = 'Phase 1 until {Termin}: shoot and copy. Phase 2 from {Termin2}: ads on {Kanal} and {Kanal2}, weekly review with {Ansprechpartner}.' }
        @{ Text = 'No radio ad: the budget won''t stretch to enough repeats. The money goes into a second wave of posters instead.' }
    )
    ConceptRisks = @(
        @{ Text = 'Open: who takes the photos? If the shoot isn''t fixed by {Termin}, we use existing images and lose credibility.' }
        @{ Text = 'The budget of {Budget} is tight. From the third round of corrections it costs more than the fixed price, and the client must know that beforehand.' }
        @{ Text = 'On the last project the client''s management turned everything upside down just before print. This time: written interim approval after the concept.' }
    )
    PrintRelease = @(
        @{ Text = 'We hereby approve the print files for {Projekt} in the version dated {Datum}. Print run {Auflage} copies. Content and spelling have been checked by us.
{Ansprechpartner}, {Kunde}' }
        @{ Text = 'Hello, attached are the final print files for {Projekt}: PDF/X-4, 3 mm bleed, run of {Auflage}. Delivery by {Termin} direct to {Kunde}. Please send a proof first.' }
        @{ Text = 'Approved with one change: correct the phone number on page 3, then everything is signed off. We don''t need another proof.' }
    )
    CustomerFeedback = @(
        @{ Text = 'The logo needs to be bigger. Much bigger.' }
        @{ Text = 'Can we make the blue friendlier? It feels so cold. But not lighter, it''s our house colour.' }
        @{ Text = 'My husband doesn''t like the photo, he says it isn''t us. Is there another one in the archive?' }
        @{ Text = 'The text is too long, nobody reads all that. Please add the opening hours, parking and the voucher anyway.' }
        @{ Text = 'On {Vortermin} we agreed on option B. Now I''m seeing A again. Please clarify.' }
        @{ Text = 'I think it''s fine as it is. But our management hasn''t looked at it yet, they''re on holiday until {Termin}.' }
        @{ Text = 'Please just put "customers" everywhere, "customers and clients" is too long. We''ll leave the website as it is.' }
        @{ Text = 'Page 2, third paragraph: the price is wrong, it should be {Betrag}. Everything else is fine, thanks!' }
        @{ Text = 'More space please, it all looks very busy. And could the team photo go on as well?' }
        @{ Text = 'In the proof the colours are much darker than on screen. Is that normal or should we be worried?' }
    )
    CancelNote = @(
        @{ Voice = 'FBloggs'; Text = '{Projekt} for {KundeKurz} on hold until further notice. Reason: budget cut at the client. {Stunden} hours worked, to be invoiced as per quote. Files to the archive.' }
        @{ Voice = 'CWhitfield'; Text = '{KundeKurz} have cancelled, they''re now doing {Projekt} in-house with a placement student. Shame, but understandable. We''ll still invoice the concept.' }
        @{ Text = 'Postponed: {Ansprechpartner} rang on {Datum}, {Projekt} won''t happen until {Quartal}. Drafts are on hold, the print order with {Lieferant} is cancelled.' }
        @{ Text = 'No response since the presentation on {Vortermin}, two follow-ups unanswered. Project on hold, follow up on {Termin}.' }
    )
    InternalComment = @(
        @{ Voice = 'FBloggs'; Text = '{Stunden} hours are not sufficient for this scope. Increase the estimate by 20 per cent.' }
        @{ Voice = 'JBloggs'; Text = 'This has turned out really well, everyone! The ending just needs one more sentence of warmth.' }
        @{ Voice = 'OBennett'; Text = 'FYI: client wants to see V2 by EOD. Headline tbc, pls 2–3 alternatives asap.' }
        @{ Voice = 'OBennett'; Text = 'Check figure vs. reporting from {Vortermin}, said sth different there. Fix by end of wk pls.' }
        @{ Voice = 'HCarter'; Text = 'I''m missing the light here – the picture stands, but it doesn''t breathe. What if we go in closer, just hands and tools?' }
        @{ Voice = 'ECollins'; Text = '1. Spell the client''s name consistently. 2. Check the date in line 4. 3. Source for the percentage is missing.' }
        @{ Voice = 'SPatel'; Text = 'Love it :-) Just the headline''s a bit tame for me.' }
        @{ Voice = 'SPatel'; Text = 'Swapped the pic, the old one was super pixelated. Is that ok?' }
        @{ Voice = 'CWhitfield'; Text = 'Cut paragraph, tells the client nothing new. Better to give the price here.' }
        @{ Voice = 'CWhitfield'; Text = 'Is the shoot in the budget? If not, do a version without and say so honestly.' }
        @{ Voice = 'GTurner'; Text = 'Just like the catalogues in the old days: facts first, then the pretty bits. The price belongs at the top.' }
        @{ Voice = 'WHughes'; Text = 'Image is 150 dpi at 100%, too low for A1. Request original, profile ISO Coated v2, 3 mm bleed missing.' }
        @{ Voice = 'TWright'; Text = 'The headline is nice. But nice is just boring in a better jumper.' }
        @{ Voice = 'ZNowak'; Text = 'Does this mean the branch address or head office? I found both and don''t want to print the wrong one.' }
        @{ Voice = 'DPrice'; Text = 'Sorry, should the logo go on the left or the right? The style guide says both. I''ve put it on the left for now, is that ok?' }
        @{ Text = 'Please check against the version from {Vortermin}, the date was different then.' }
        @{ Text = 'Agreed with {Ansprechpartner}? If not, better take it out.' }
        @{ Text = 'Source for this figure? The client will ask.' }
    )
    ReportSummary = @(
        @{ Text = 'Period {Termin} to {Termin2}: {Prozent}% more enquiries than the previous year. Online target met, print fell short of expectations.' }
        @{ Text = 'On budget: {Betrag} of {Budget} spent. {Kanal} brought the most enquiries, {Kanal2} hardly any measurable effect.' }
        @{ Text = 'Lots of attention, fewer sales than planned. The client is happy all the same and wants to follow up in {Quartal}.' }
    )
    ReportLearnings = @(
        @{ Text = 'Photos of real staff performed much better than stock images. Next time, plan a shoot in from the start.' }
        @{ Text = 'Twice we lost a week because approvals were missing. In future, fixed approval dates in the schedule.' }
        @{ Text = 'Hardly anyone used the QR code on the poster. A short web address works better.' }
    )
    PressHeadline = @(
        @{ Text = '{Kunde} launches {Projekt}' }
        @{ Text = '{KundeKurz}: something new from {Termin2}' }
        @{ Text = 'From {Stadt}, for {Stadt}: {KundeKurz} backs {Produkt}' }
    )
    PressBody = @(
        @{ Text = '{Stadt}, {Datum}. From {Termin2}, {Kunde} will be appearing on {Kanal} and {Kanal2} with {Projekt}. At its heart is {Produkt}. The campaign was developed by {Firma}.' }
        @{ Text = '{Stadt}, {Datum}. {Kunde} is expanding its range around {Produkt}. Anyone who gets in touch by {Termin} can preview the changes.' }
        @{ Text = '{Stadt}, {Datum}. More than {Auflage} people visited {KundeKurz} last year. With {Projekt}, the team aims to reach new audiences.' }
    )
    PressQuote = @(
        @{ Text = '“We didn''t want to be louder, just clearer,” says {Ansprechpartner}. “People should see who works here.”' }
        @{ Text = '“The brief was short, the discussions were long,” says {Ich} of {Firma}. “In the end the simplest idea won.”' }
        @{ Text = '“We''ve been in {Stadt} for years and we want to stay here,” says {Ansprechpartner}.' }
    )
    NextStep = @(
        @{ Text = 'Incorporate corrections by {Termin}' }
        @{ Text = 'Get approval from {Ansprechpartner}' }
        @{ Text = 'Print files to {Lieferant} by {Termin2}' }
        @{ Text = 'Review with the client at the end of {Monat}' }
    )
}
