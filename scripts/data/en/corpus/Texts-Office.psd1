# Protokolle, Briefe, Rundschreiben, Notizen, UK-Variante (siehe README.md)
@{
    MinutesTopic   = @(
        @{ Title = 'Workload'; Text = 'We''re {Prozent} % over plan in {Monat}, {KollegeVorname} has {Stunden} hours outstanding. No more capacity.
{Leitung} wants to give final artwork to freelancers. Against: the last one botched the bleed, two reprints.
Outcome: only non-critical jobs go out. {Ich} checks by {Termin} what can be moved.' }
        @{ Title = 'Project status {KundeKurz} – {Projekt}'; Text = '{Projekt} stuck since {Vortermin}, no sign-off, {Ansprechpartner} on holiday. {Prozent} % of budget used.
{KollegeVorname} wants to start artwork anyway. {Ich} against: if the client changes the colours after, we do it all twice.
Outcome: only after written sign-off. {Kollege} rings Monday, start on {Termin2} if need be.' }
        @{ Title = 'Holiday planning'; Text = 'Three requests for the same two weeks from {Termin}, right in the busy phase for {KundeKurz}. Not possible.
Parents first? {KollegeVorname} thinks that''s unfair. Agreed: parents first only in school holidays, whoever missed out last year goes first.
List in the Departments share, fill in by {Termin2}. Then {Leitung} decides.' }
        @{ Title = 'New enquiry {KundeKurz}'; Text = '{Ansprechpartner} rang on {Vortermin}: more advertising for {Produkt}, via {Kanal} and {Kanal2}, budget roughly {Budget}.
{KollegeVorname}: the money covers one channel. {Ich} sees a potential regular client.
Outcome: quote in two versions. {Ich} writes it by {Termin}, {Kollege} costs the hours.' }
        @{ Title = 'Trouble with the printers'; Text = 'Posters for {KundeKurz} two days late, red far too pale. Printers blame our colour profile. {KollegeVorname} checked: ISO Coated v2, 3 mm bleed, all correct.
Switch? {Leitung} won''t rush it, five good years.
Outcome: complaint with photos, reprint at their cost, {Ich} by {Termin}. Comparison quote next time.' }
        @{ Title = 'File server full'; Text = 'Server 94 % full, {KollegeVorname} couldn''t save on Tuesday. Big items: raw shoot files twice, in H: and Projects, “Backup old” with 180 GB.
{Ich} wants to buy disks, {Leitung} wants a tidy-up first.
Outcome: tidy home folders by {Termin}, projects over two years old to Archive. {Kollege} asks the IT provider for prices.' }
        @{ Title = 'Printer in the corridor'; Text = 'Paper jam in tray 2 almost daily. Engineer came on {Vortermin}, lasted three days.
{KollegeVorname} wants a replacement. {Ich} wants to check the meter readings first, maybe we just print too much.
Outcome: tray 2 out of use (note on it), {Ich} writes to the leasing company, deadline {Termin}.' }
        @{ Title = 'Christmas party'; Text = 'Together or separate? {KollegeVorname}: separate, the trip back to Manchester was too much last year. {Leitung}: the one evening a year we''re all together.
Outcome: together in London, hotel for Manchester. £55 a head plus travel, Secret Santa up to £10. Venue poll by {Termin} ({Kollege}).' }
        @{ Title = 'Working-from-home rules'; Text = 'Complaint from {KundeKurz}: nobody picks up on Tuesdays and Fridays. {Leitung} wants fixed office days, {KollegeVorname} doesn''t – too much chatter in the office.
Outcome: Wednesday is office day for all, team meeting 10 am. Divert phones to the laptop, not personal mobiles. From {Termin}, {Ich} updates the policy.' }
        @{ Title = 'New colleague'; Text = 'New designer starts {Termin}, desk by the window. Laptop only arrives the day before – tight.
{KollegeVorname} knows the layout software best but has no time. Agreed: first week {Kollege}, then {Ich} as buddy.
{Ich} requests the account, {Kollege} the keys. First day: lunch together.' }
        @{ Title = 'Price increase'; Text = 'Hourly rates unchanged for three years, rent and salaries not. {Ich} proposes plus 8 % from {Termin2}.
{KollegeVorname} worries about the nursery, the club and the music school. {Leitung} doesn''t want two price lists.
Outcome: 8 % for all, 10 % charity discount stays. Client letter {Ich} by {Termin}, {Kollege} proofreads.' }
        @{ Title = 'Image rights claim'; Text = 'Claim against {KundeKurz}: unlicensed photo on the landing page, £1,250 plus legal costs. Was a placeholder in the draft of {Vortermin}.
{KollegeVorname} is sure we bought the licence, nobody can find the invoice. {Leitung}: sign nothing until it''s clear.
Outcome: {Kollege} looks for the licence, {Ich} informs client and solicitor, deadline {Termin}. Placeholders only with watermark from now on.' }
    )
    LetterCustomer = @(
        @{ Subject = 'Confirming our meeting: {Projekt}'; Text = 'As agreed, we will visit you in {Stadt} on {Termin} at 10 am to go through the designs for {Projekt}. We will bring three options.
Ideally the person who gives final sign-off will be there too – it saves a round of amends.' }
        @{ Subject = 'Thank you for {Projekt}'; Text = 'The “{Claim}” campaign is complete, and we want to thank you personally. It wasn''t always easy – remember the evening before the print deadline? – but {Kanal} brought {Prozent} % more enquiries than last year.
You will have the report by {Termin}.' }
        @{ Subject = 'Season''s greetings'; Text = 'Thank you for a good year, quick feedback and the odd debate that led to a better result.
Our office is closed from 24 December to 1 January. Have a restful Christmas and a happy New Year.' }
        @{ Subject = 'Changes to our hourly rates'; Text = 'Our prices have not changed for three years; rent, salaries and licences have. From {Termin2} our hourly rates rise by 8 %.
Quotes accepted by {Termin} will still be charged at the current rate.' }
        @{ Subject = 'Query about image rights'; Text = 'For {Projekt} you would like to use the photos from {Vortermin}. For six of them we don''t know who took them or whether you hold print and web rights, and two show identifiable people.
Please confirm by {Termin} – a copyright claim would cost far more.' }
    )
    LetterSupplier = @(
        @{ Subject = 'Complaint: order {Projekt}'; Text = 'We cannot accept the flyers for {Kunde} delivered on {Vortermin} (print run {Auflage}, A5):
• House red clearly shifted towards orange, visibly different from the proof.
• On about a third of sheets the trim cuts up to 2 mm into the artwork, despite 3 mm bleed.
• Smear marks on the right edge in several boxes.
Photos enclosed. Please reprint at your cost by {Termin}; distribution starts on {Termin2}.' }
        @{ Subject = 'Proposal: framework agreement'; Text = 'We have worked together for five years, lately on around 40 jobs a year. We propose a two-year framework agreement: fixed tiered prices, free delivery, five working days'' production. In return we commit to £25,000 net a year.
Would a meeting on {Termin} suit you?' }
        @{ Subject = 'Rescheduling {Projekt}'; Text = 'Unfortunately we need to move the slot booked for {Termin}, as our client has not yet approved the files. Would {Termin2} be possible?' }
        @{ Subject = 'Termination of lease: multifunction printer'; Text = 'We hereby give notice to end the lease for the multifunction printer at our {Standort} office as of {Termin2}.
Since {Vortermin} we have needed four engineer call-outs, and the promised replacement never came. Please confirm and propose a collection date.' }
    )
    Reminder       = @(
        @{ Level = 1; Text = 'We have not yet received payment of the invoice below. No doubt an oversight. Please transfer the amount by {Termin}. If you have paid in the meantime, please ignore this letter.' }
        @{ Level = 1; Text = 'Your invoice for {Projekt} has been due since {Vortermin}. Perhaps it landed on the wrong desk? Please pay by {Termin}; any questions, just give us a call.' }
        @{ Level = 2; Text = 'Despite our reminder of {Vortermin}, your payment has not arrived. We now claim the amount plus £40.00 statutory late payment compensation, due by {Termin}. After that the debt goes to a collection agency.' }
        @{ Level = 2; Text = 'You have not responded to our reminder of {Vortermin}, and the invoice is over 30 days overdue. Please pay by {Termin}. Until payment arrives, we are putting further work on your projects on hold.' }
    )
    Announcement   = @(
        @{ Event = 'Founding'; Subject = 'It''s official!'; Text = 'Hello all, as of today {Firma} is registered at Companies House! Thanks to Oliver, sitting with Fred and me among the boxes at 8 Chestnut Avenue, and to David, who is rescuing our receipts from the shoebox.
First job: flyers for Crumb & Crust Bakery. Bubbly in the office Friday from 5 pm!
Jane' }
        @{ Event = 'Hamburg'; Subject = 'Manchester branch office'; Text = 'Dear colleagues,
30 % of our turnover now comes from the North West, and travelling costs us a working day a week. On 1 September we open an office in Manchester, 1 Mill Lane, headed by Charlotte Whitfield, with George Turner and James Morris.
Fred Bloggs' }
        @{ Event = 'Move'; Subject = 'We''re moving!'; Text = 'Hello all, at the end of June we move from 8 Chestnut Avenue to 1 Market Way – finally a meeting room with a door!
Please clear your desks and label boxes with your name and room number. The IT provider moves the computers, phone numbers stay. Comfy shoes!
Jane' }
        @{ Event = 'Rebranding'; Subject = 'Our new look'; Text = 'Hello all, from Monday we look different! Out go burgundy and Times, in come petrol blue, orange and Arial. Under the logo, “Advertising that gets through.” becomes “Communication and design agency”.
Please use only the new templates. Old business cards become notepads. Thank you, Harry and Emily, for six months of work!
Jane' }
        @{ Event = 'Scanner'; Subject = 'New scanner in the corridor'; Text = 'Hi all, the new machine in the corridor now scans too: insert document, “Scan to folder”, tap your name, Start. PDFs land in the Scans share, in a subfolder with your name. Please move them to the project folder promptly – Scans is not an archive.
Natalie' }
        @{ Event = 'Homeoffice'; Subject = 'Working from home'; Text = 'Dear colleagues,
from 1 April up to two days a week working from home are possible, agreed within the team. Core hours 10 am to 3 pm. Company laptop with VPN only, no client data on personal devices. Review after six months.
Fred Bloggs' }
        @{ Event = 'Anniversary'; Subject = '10 years of {Firma}!'; Text = 'Hello all, ten years ago Fred, Oliver and I sat in Chestnut Avenue, the three of us and a printer that only worked on Mondays. Today we are 14 people in London and Manchester. We celebrate on the last Saturday in March from 6 pm at 1 Market Way. Let me know by 10 March!
Jane' }
        @{ Event = 'FileServer'; Subject = 'New file server – please read'; Text = 'Dear colleagues,
this weekend our data moves to the new file server. Don''t save anything after 4 pm on Friday. From Monday:
• H: is your personal drive, for working files only.
• Client work goes in Projects, one folder per client and project; team documents in Departments.
• Move projects older than two years to Archive by end of November.
• No private files, photos or music on the server.
Questions to Oliver or support, +44 20 7946 0777.
Fred Bloggs' }
        @{ Event = 'CustomerLost'; Subject = '{KundeKurz}'; Text = 'Dear colleagues,
there is no good way to say this: {Kunde} has awarded the tender to another agency. We were 15 % above the cheapest bid. That is around 22 % of our turnover.
There will be no redundancies, but no new hires for now either. Seven years of work went into this client. It was not down to you. Let us talk it through on Thursday at 10 am.
Fred Bloggs' }
        @{ Event = 'FrameworkContract'; Subject = 'Framework agreement {KundeKurz}'; Text = 'Hi all, {Kunde} has signed a three-year framework agreement: property brochures, site hoardings, website, around 1,400 hours a year. Thanks for the late nights before the pitch!
It also means Manchester is full from October. George leads, Zofia and William deliver. New enquiries through me first, please.
Charlotte' }
        @{ Event = 'Christmas'; Subject = 'Christmas party {Jahr}'; Text = 'Hello all, we celebrate on the second Friday in December from 4 pm in London. Secret Santa up to £10, names drawn at the team meeting. Vegetarian, vegan, allergies? Tell me by end of November. And yes, Oliver is doing a quiz again!
Jane' }
        @{ Event = 'Summer'; Subject = 'Summer party {Jahr}'; Text = 'Hi all, FYI:
• last Fri in June, 3 pm, Manchester this time, by the canal
• BBQ + drinks sorted, everyone brings a salad, list asap
• London takes the 10:30 train, plan B if it rains tbc
RSVP by wk 24. Kids welcome!
Oliver' }
    )
    HomeNote       = @(
        @{ Voice = 'FBloggs'; Text = 'Cash flow {Monat}: in £32,500, out £35,500. {KundeKurz} not paying. Call accountants re VAT payment.' }
        @{ Voice = 'JBloggs'; Text = 'Team breakfast Friday: order pastries, Sophie''s doing the playlist! Card for {KollegeVorname} is in the drawer!' }
        @{ Voice = 'OBennett'; Text = 'To-dos wk: finalise pitch {KundeKurz} asap, media plan {Kanal} tbc, 1:1 w/ Sophie Thu 2pm' }
        @{ Voice = 'HCarter'; Text = 'Idea {KundeKurz} – don''t show the product, show the moment after: crumbs, an empty plate, warm side light, lots of white space.' }
        @{ Voice = 'ECollins'; Text = 'Print files {Projekt}:
1. Bleed ok
2. Fonts embedded
3. Cover image only 240 dpi, query
4. Sign-off missing' }
        @{ Voice = 'SPatel'; Text = 'Name files properly!!! No more final_final2.indd :-) Ask Emily how Package works.' }
        @{ Voice = 'CWhitfield'; Text = 'Call {Ansprechpartner}: budget''s there if the brochures come 2 weeks earlier. George builds templates. Quote by {Termin}.' }
        @{ Voice = 'GTurner'; Text = 'Insist on a paper proof for {KundeKurz}. In my day we signed off at the light table, now it''s a tick box in a portal.' }
        @{ Voice = 'WHughes'; Text = '{KundeKurz}: FOGRA39, orange 0/60/100/0, no RGB conversion by them. A1 poster: 150 dpi is enough.' }
        @{ Voice = 'TWright'; Text = 'Claim {KundeKurz}: “Less natter, more matter.” Pun count today: 3. Charlotte allows 2.' }
        @{ Voice = 'ZNowak'; Text = 'Before final artwork, ask {Ansprechpartner}: keep the old logo on the back? New phone number? Is everyone happy with the team photo?' }
        @{ Voice = 'DPrice'; Text = 'Ask George if I''m allowed to send out the poster files myself. Sorry again about the wrong version. Templates in H: or Projects??' }
        @{ Text = 'Call back {Ansprechpartner} re {Projekt}: was to say by {Termin} if {Kanal2} gets added. Chase Wed.' }
        @{ Text = 'Printers'' portal login expires {Termin}. New password NOT on the sticky note on the monitor again.' }
        @{ Text = 'Hours {Projekt}: Mon 3.5 / Tue 6 / Wed 2 amends / Thu 4 – still to log!' }
    )
    PrivateNote    = @(
        @{ Subject = 'Summer holiday'; Text = 'Cornwall, holiday cottage £95/night, 2 weeks approx. £1,300. Or camping at Lake Garda, but the kids want a pool. Book by end of January!' }
        @{ Subject = 'Flat hunting'; Text = 'Thu 6 pm 14 Garden Street, 2 bed, £1,650 pcm incl. bills, 4th floor, no lift. Sat 11 am 3 Linden Avenue, £1,400 pcm. Bring references, credit report!' }
        @{ Subject = 'Presents'; Text = 'Mum: photo book from the summer. Jack: climbing shoes size 6. Gran: chocolates without alcohol! Max. £200 total.' }
        @{ Subject = 'Lentil soup (Gran)'; Text = 'Soak 250 g green lentils, onion, 2 carrots, celery, 2 potatoes, 1.5 l stock, 40 min. Finish with vinegar and sausages.' }
        @{ Subject = 'Shopping list'; Text = 'Milk, oats, bananas, raclette cheese, wine for Annie, AA batteries, coffee!!! Collect parcel from post office.' }
        @{ Subject = 'Selling the bike'; Text = 'Hybrid bike, 700c, 52 cm frame, new tyres. £150 ono, not under £120. Mr Summers coming to look on Sunday.' }
    )
}
