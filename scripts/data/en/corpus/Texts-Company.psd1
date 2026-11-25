# Richtlinien, Handbücher, Verträge, IT-Dokumentation, englisch (siehe README.md)
@{
    Policy = @(
        @{ Title = 'IT Policy'; Folder = 'IT'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Scope'; Text = 'This policy applies to everyone who has an account at {Firma}: employees, apprentices, interns and freelancers. We have no IT department of our own. Eastside IT Services Ltd looks after the technical side; decisions are made by the directors.' }
                @{ Title = '2 Passwords'; Text = 'A password has at least 12 characters. A good one is a sentence only you know, say four words and a number. Names of children, pets and football clubs are bad ones.
Passwords are not written on notes, neither on the monitor nor under the keyboard, and never kept in a file called "Passwords.xlsx" on H:. Not even your holiday cover gets your password; that is what group permissions and mailbox delegation are for.
Nobody here or at Eastside IT will ever ask for your password. When you leave your desk, lock the screen with Windows key + L.' }
                @{ Title = '3 Storing files on the file server'; Text = 'Business files belong on the file server, not on the desktop. Only the server is backed up.
• H: is your home folder (share Home$), for you alone: drafts and notes nobody needs yet.
• Departments: one folder per department. Everyone can read General, where policies and templates are kept.
• Projects: one folder per job, named Year_Client_Project, containing 01_Quote to 06_Invoicing.
• Archive: closed years, read only. Only management moves things into the Archive.
• Scans: the inbox of the multifunction printer. Everyone can see everything here, so collect your scans the same day and file them properly.
Private photos, music and films do not belong on the server. Client data never goes on USB sticks; print files go through the print supplier''s upload portal.' }
                @{ Title = '4 Email'; Text = 'Do not open attachments you were not expecting, not even an "invoice" or a "job application". Send files over 20 MB as a download link. Work emails are not forwarded to private mailboxes.
If a supplier emails to say their bank details have changed, call them on the number in our records, not the one in the email.' }
                @{ Title = '5 Backup and previous versions'; Text = 'The file server is backed up every night and creates previous versions at 7:00 and 12:00 on working days. You can get an overwritten file back yourself: right-click, Properties, Previous Versions. Choose "Restore to..." and save the old version next to the current one, so nothing is lost.
Older versions are restored from backup by Eastside IT. Anything on your desktop is not backed up anywhere.' }
                @{ Title = '6 If you suspect something'; Text = 'Clicked a link, an attachment behaves oddly, files suddenly have different names, laptop gone: call Eastside IT Services (+44 20 7946 0777) and the directors straight away. If you suspect malware, unplug the network cable and switch off Wi-Fi, but do not shut the device down.
Nobody gets into trouble for falling for something and reporting it at once. Trouble only comes from keeping quiet.' }
            ) }
        @{ Title = 'Data Protection Policy'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Principle'; Text = 'We work with other people''s data every day: mailing lists, competition entrants, job applications, salaries. We collect only what the job needs, keep it only as long as necessary and show it only to those who work with it. At our size we do not need a Data Protection Officer; the contact is Jane Bloggs. We are registered with the ICO.' }
                @{ Title = '2 Job applications'; Text = 'Applications are seen only by HR and management. They are kept in Departments\HR\Applications, not in a mailbox and not on H:. Team members who help decide see the file in the interview but do not get it forwarded.
Six months after a rejection we delete documents and emails, unless the applicant has agreed in writing to stay in our talent pool.' }
                @{ Title = '3 Competitions for clients'; Text = 'Entrant data is used only for the draw and to notify the winners. After the draw we delete the list, and the winners'' addresses once the prizes have been sent. The list is kept in the project folder only, never as a copy on H: or in a mailbox. Three versions of "Entrants_final.xlsx" are three deletions someone will forget.' }
                @{ Title = '4 Personnel files'; Text = 'Personnel files, payslips, sick notes and formal warnings are seen only by HR and management. They are never scanned via the Scans share, because everyone can read along there. Sick notes are health data, a special category under UK GDPR; we do not ask for the diagnosis. The head of office is told who is off and for how long, nothing else.' }
                @{ Title = '5 Retention periods'; Text = 'We keep what the law requires, and no longer:
• 6 years: accounting records, invoices, bank statements, annual accounts (HMRC)
• 6 years: business letters and emails, quotes that turned into a job (contract claims: six years)
Periods run from the end of the financial year. Every January management clears out the Archive.' }
                @{ Title = '6 Processors'; Text = 'Anyone processing personal data for us needs a data processing agreement (Article 28 UK GDPR) first, above all Northern Lights Print (addresses for mailings) and Eastside IT Services. Addresses go only through the print supplier''s upload portal, never as an Excel attachment. After the mailing the printers confirm deletion; the confirmation goes into the project folder under 06_Invoicing.' }
                @{ Title = '7 Data breaches'; Text = 'Email to the wrong distribution list, laptop left on the train: tell the directors immediately. If the breach has to be reported to the ICO, we have 72 hours from the moment we become aware of it.' }
            ) }
        @{ Title = 'Classification Policy'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Why four levels'; Text = 'A flyer lying on the counter of a bakery can be seen by anyone, a salary list not even by half the team. So that nobody has to guess, every document gets one of four levels. Whoever creates the document sets the level. If in doubt, the higher one applies.' }
                @{ Title = '2 Public'; Text = 'Anything that is or may be published: press releases once approved, job adverts, our website, campaign artwork after launch. Note: finished artwork only becomes public on the launch date; until then it is confidential.' }
                @{ Title = '3 Internal'; Text = 'Meant for our team, but no harm done if it gets out by mistake: policies, templates, minutes of the team meeting, phone list, holiday planner. Internal is the default level; anything without a label counts as internal.' }
                @{ Title = '4 Confidential'; Text = 'Anything that would harm us or a client if the wrong people read it: quotes and costings, briefings, unpublished drafts, contracts, client lists, management accounts, the IT emergency handbook. Only for the people on the project and the client; sent outside only encrypted or as a link with an expiry date. Printouts are not left lying in the printer.' }
                @{ Title = '5 Strictly confidential'; Text = 'Data about individuals that could seriously harm them: personnel files, salaries and payslips, sick notes and all other health data, formal warnings, job applications, bank details, login credentials. Such documents are kept only in Departments\HR or Departments\Management, are not emailed out, not scanned via the Scans share and not stored on H:. Printouts go into the directors'' lockable cabinet.' }
                @{ Title = '6 Labelling'; Text = 'The level appears on the right of the header and again in the footer, e.g. "Classification: Confidential". In Excel it goes into the header of every sheet, in PowerPoint on the slide master. With sensitivity labels in Office you choose the level with the "Sensitivity" button, and the app adds header and footer itself.
A file name is not a label. "Salaries_SECRET.xlsx" is not protection, it is a signpost.' }
            ) }
        @{ Title = 'Home Working Policy'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Extent and agreement'; Text = 'If you wish, you can work from home up to two days a week, apprentices one. Agree the days with your head of office and enter them in the team calendar by Friday for the following week. Monday at 9:30 is the team meeting, when everyone is in the office; Manchester joins by video.' }
                @{ Title = '2 Availability'; Text = 'Between 10:00 and 15:00 you are reachable just as in the office: phone diverted, calendar up to date. Client meetings on site and deadlines come first. Whoever is responsible for the print files on deadline day is in the office. Working hours, rest breaks and finishing time apply at home just the same.' }
                @{ Title = '3 Equipment and connection'; Text = 'Work only on the company laptop, not on a private PC. You reach the file server via VPN; no VPN, no H: drive. We provide a monitor, keyboard and headset on request; internet and electricity are your own. Only you use the laptop, not the family, and not for homework.' }
                @{ Title = '4 Confidentiality at home'; Text = 'Take client calls where nobody can overhear, so not on the balcony. Printouts with client data come back to the office and go into the shredder there, not the recycling. Strictly confidential documents do not leave the office at all.' }
                @{ Title = '5 Disruptions'; Text = 'If the internet or power goes down at home, come into the office or, by agreement, take time off in lieu. Report an accident while working to the directors straight away, just as in the office.' }
            ) }
        @{ Title = 'Travel Expenses Policy'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Approval'; Text = 'Business trips are approved in advance by the directors, in Manchester by the head of office. A short email with purpose, date and means of transport is enough. Between London and Manchester we take the train, standard class with a seat reservation. Use the car only if equipment has to come along (trade fair, photo shoot) or the appointment cannot be reached any other way.' }
                @{ Title = '2 Travel costs'; Text = 'For your own car we pay HMRC''s rate of 45p per mile, by route planner and without detours. Parking and local transport against receipts. Taxis only if there is no other way, say with two roll-up banners and an exhibition case.' }
                @{ Title = '3 Meals and overnight stays'; Text = 'We pay HMRC''s benchmark subsistence rates: £5 when away more than 5 hours, £10 over 10 hours, £25 over 15 hours. Meals already paid for, such as hotel breakfast or a lunch with a client, are not claimed again.
Book hotels up to £120 a night yourself, dearer ones after checking with us. The invoice must be made out to {Firma} at the London address, otherwise we cannot reclaim the VAT.' }
                @{ Title = '4 Receipts and claims'; Text = 'Claims are made on the form in Departments\General\Templates by the 10th of the following month. Scan your receipts at the multifunction printer into the Scans share, file name TravelExpenses_Name_Date. Accounts moves them from there into its own folder. Nobody needs their own permissions on Departments\Accounts for this, not even as an exception.
Originals go in an envelope marked with name and month into the Accounts tray at London reception; Manchester sends them in one batch at month end. Thermal paper fades, so scan first, then hand in. Expenses are repaid with the next payroll.' }
            ) }
        @{ Title = 'IT Emergency Handbook'; Folder = 'IT'; Classification = 'Confidential'; Sections = @(
                @{ Title = '1 What this handbook is for'; Text = 'It describes the first hours after an IT failure, even when no expert is in the building. Printed copies are kept in the red binder in the London server room, with the head of the Manchester office and at the directors'' homes. An emergency handbook that only exists on the failed server helps nobody. The directors check numbers and names every January.' }
                @{ Title = '2 Contacts'; Text = '• Eastside IT Services Ltd: +44 20 7946 0777, Mon–Fri 8:00–18:00; outside these hours emergency call-out on the same number, chargeable
• Directors: Fred Bloggs, +44 20 7946 0100, deputy Jane Bloggs, +44 20 7946 0500
• Manchester office: Charlotte Whitfield, +44 161 496 0100
Only the directors may order an emergency call-out.' }
                @{ Title = '3 File server failure'; Text = '1. Is it just one desk? If the neighbours can open H: and Projects, the problem is the workstation, not the server.
2. If it affects everyone: check in the server room whether the server is running and the UPS is beeping. Do not switch it off and on again, least of all during the nightly backup.
3. Call Eastside IT: since when, who is affected, what was changed last.
4. Until it is fixed, everyone works in a folder called Emergency on their desktop and copies the files back themselves afterwards.
5. If deadlines are due, the project lead calls the client the same day.' }
                @{ Title = '4 Suspected ransomware'; Text = 'Signs: files will not open or have a strange extension, new text files demanding payment appear in folders.
1. Unplug the network cable, Wi-Fi off. Do NOT switch the device off: its memory holds traces for the investigation.
2. Photograph the screen with your phone, note the time.
3. Call Eastside IT and the directors, do not email.
4. Open nothing else, plug in no USB sticks, try nothing out.
5. No contact with the blackmailers, no payment. The directors decide on reporting to the police and notifying the ICO (72 hours).' }
                @{ Title = '5 Recovery'; Text = 'Eastside IT manages the recovery together with the directors:
1. Cause removed, affected devices reinstalled.
2. Domain controllers first, then the file server, then the mail server.
3. Restore from the last clean backup: Projects first, then Departments, Home$ last.
4. New passwords for everyone, service accounts included.
5. Each department checks samples before normal work resumes.
Afterwards the directors write down what happened, what helped and what we will change.' }
            ) }
    )

    CiHandbook = @(
        @{ Title = '1 Brand essence'; Text = 'When Fred and Jane Bloggs founded the agency, our mark was a dark red wordmark in a serif typeface. It suited two people making brochures for small businesses. With Manchester, social media and screens everywhere it became a problem: illegible as a profile picture, a grey bar on a fax, and next to client logos the red looked like proof corrections.
The new mark is a "C" made of two shapes. Petrol stands for reliability: deadlines, artwork, craft. Orange for the idea nobody saw coming. Only together do they form the C, just like London and Manchester, concept and execution. Next to it stands the wordmark "Contoso".' }
        @{ Title = '2 Logo and clear space'; Text = 'The logo comes in three versions: horizontal (standard for letterhead, documents, website), stacked (square formats, roll-up banners) and the symbol alone (favicon, profile picture).
Minimum size of the horizontal version: 20 mm wide in print, 120 px on screen. Below that, use the symbol alone.
Around the logo, keep a clear space as wide as the C is tall. Nothing reaches into it: no text, no image edge, no fold. All files are in the Branding folder, as PDF for print and as PNG and SVG for screen.' }
        @{ Title = '3 Colours'; Text = 'Petrol is the main colour, orange adds accents. Rule of thumb: no more than a tenth of a page is orange.
• Petrol: HEX #005461, RGB 0/84/97, CMYK 100/30/20/50
• Orange: HEX #E87722, RGB 232/119/34, CMYK 0/60/95/0
• Light grey: HEX #F2F2F2, RGB 242/242/242, for panels and table rows
• Charcoal: HEX #333333, RGB 51/51/51, for body text instead of pure black
Orange is too light for body text on white; use petrol or charcoal for that. On uncoated paper, ask for a proof first, as petrol tends to turn greyish there.' }
        @{ Title = '4 Typography'; Text = 'For documents we use Arial, for presentations and screen Segoe UI. Both are on every computer, so clients see our files exactly as we built them.
• Body text Arial 10 pt, charcoal, line spacing 1.3
• Heading 1 Arial 16 pt bold, petrol; Heading 2 Arial 12 pt bold, charcoal
• Footer and small print Arial 7.5 pt
Ranged left, ragged right, never justified. Client projects use the client''s fonts; this handbook only covers our own identity.' }
        @{ Title = '5 Letterhead and documents'; Text = 'Letters are fully blocked with open punctuation, the address placed for a DL window envelope. The logo sits top right, 45 mm wide. The footer has three columns: London address, Manchester address, bank details with company number and registered office (Companies House).
Always use the templates from Departments\General\Templates. Never copy an old letter to write over it: many older files still carry the red logo, and you only notice when the client rings.
The classification is on the right of the header; file names start with the date (YYYY-MM-DD_Client_Topic).' }
        @{ Title = '6 Presentations'; Text = 'The template is 16:9. The title slide is solid petrol with the logo in white; content slides are white with a small symbol bottom right.
• Segoe UI, no smaller than 20 pt
• six bullet points at most; anything that needs more belongs in the handout
• client logo only on the title and closing slides
• photos full-bleed, without frames or shadows
The closing slide names a contact with a direct dial. Just "Thank you" is not enough.' }
        @{ Title = '7 Social media and email'; Text = 'The profile picture is the symbol, white on petrol. In the round crop the C must sit entirely inside the circle, so check before uploading.
Our images show real people doing real work: the team at the layout table, a proof held against the light, hands on a client''s cargo bike. No stock photos of handshakes in front of glass office blocks.
The email signature is text plus logo at 120 px wide: name, role, direct dial, office. No slogans, no banners.' }
        @{ Title = '8 Dos and don''ts'; Text = 'Please do:
• always take the logo from the Branding folder, never copy it from an old file
• on photos, place it only on calm areas, otherwise on a petrol panel
• single-colour only entirely in charcoal or entirely in white
Please don''t:
• distort, rotate or crop it, or add shadows, outlines or gradients
• swap the colours of the two shapes
• place it on busy photos or patterns
• use the old red wordmark, not even "just internally". Old business cards and stamps are thrown away, not used up.
Questions about the CI go to Emily Collins.' }
    )

    BrandingGuide = @(
        @{ Title = '1 Goal'; Text = 'Anyone signing in to Microsoft 365 used to see Microsoft''s standard page, and that is exactly what phishing emails copy. With our logo, our colours and a notice of our own, the real sign-in page looks unmistakably like {Firma}. If the logo is missing, everyone should stop and enter nothing.
Branding does not replace multi-factor authentication, because our logo can be copied too. But it makes crude fakes stand out.' }
        @{ Title = '2 Prerequisites'; Text = '• An account with the "Organizational Branding Administrator" role. Global Administrator would work too but is far too powerful for this. The role is assigned for the setup and removed again afterwards.
• A licence that includes company branding, such as Entra ID P1 or Microsoft 365 Business Standard.
• The files from the Branding folder. They were exported according to the CI handbook; please do not crop or re-save anything yourself.' }
        @{ Title = '3 Which file goes where'; Text = '• Favicon (Basics): favicon_32x32.png, 32 x 32 px, max. 5 KB
• Background image (Basics): background_1920x1080.jpg, 1920 x 1080 px, max. 300 KB
• Page background colour (Basics): #005461, visible while the image loads
• Header logo (Header): logo_header_245x36.png, 245 x 36 px, max. 10 KB
• Banner logo (Sign-in form): logo_banner_245x36.png, 245 x 36 px, max. 50 KB
• Square logo, light and dark (Sign-in form): logo_square_light.png and logo_square_dark.png, each 240 x 240 px, max. 50 KB
• Edge for Business: edge_logo.svg (wider than tall) and edge_taskbar.svg (square), each max. 150 KB
The subfolder with the old logos still holds the red wordmark and the old favicon. They are not uploaded. Rule of thumb: anything dark red or with serifs is old.' }
        @{ Title = '4 Step by step'; Text = '1. Sign in to the Entra admin center with the branding account.
2. Open Entra ID > Custom Branding and click Edit under Default sign-in.
3. Basics: favicon, background image and background colour.
4. Layout: template with a partial-screen background, so the sign-in box does not cover the photo; show the header.
5. Header: header logo.
6. Footer: point the "Privacy & Cookies" link to our privacy page.
7. Sign-in form: banner logo, both square logos, username hint, sign-in page text.
8. Review + create, check everything, Create.
Edge is set up in the Microsoft 365 admin center via the Edge management service (configuration policy, Organization branding).' }
        @{ Title = '5 Sign-in page texts'; Text = 'The texts are ready in the document "Sign-in Page Texts", agreed with the directors. Please copy them word for word.
• Username hint: max. 64 characters, "Your work email address"
• Sign-in page text: the long notice, max. 1024 characters
• Short notice (150 characters) and support (300 characters): for the new notice fields, as soon as our tenant offers them
• Footer: link text and address for privacy and terms of use
The sign-in page is public: no direct dial numbers, no server names, no staff names.' }
        @{ Title = '6 Checking'; Text = 'Changes take a while; allow up to an hour.
1. Open a private browser window, so nothing comes from the cache, and go to the Microsoft 365 sign-in page.
2. Enter a test account without admin rights. As soon as the name is recognised, the background, banner logo and notice appear.
3. Check the favicon in the tab, then on a phone and in dark mode.
If everything is right: remove the role again and put a screenshot in the Branding folder.' }
    )

    SignInText = @(
        @{ Title = 'Short notice'; Text = 'For Contoso staff only. If our logo is missing at the top, enter nothing and call the IT helpdesk.' }
        @{ Title = 'Long notice'; Text = 'Use this page to sign in to your Contoso work account. Before you enter your password, check two things: can you see our logo, the C in petrol and orange? And did you start this sign-in yourself?
We never ask for your password or a verification code by email, chat or phone. If your phone shows a sign-in request you did not trigger, deny it and contact the IT helpdesk.
On other people''s computers, please do not choose "Stay signed in", and sign out when you have finished.
Lost your laptop or phone? Report it at once, even at the weekend: +44 20 7946 0777.' }
        @{ Title = 'Support'; Text = 'Problems signing in? IT helpdesk Mon–Fri 8:00–18:00: +44 20 7946 0777 or support@contoso.example.com. Please give your name, office and the error message; a photo of the screen helps.' }
        @{ Title = 'Footer'; Text = 'Privacy: https://www.contoso.example.com/privacy
Terms of use: https://www.contoso.example.com/it-use
© {Firma}, London and Manchester' }
    )

    Agreement = @(
        @{ Title = 'Lease of Office Premises, London'; Party = 'Central Property Management Ltd'; Sections = @(
                @{ Title = '1. Premises'; Text = 'The landlord lets the offices on the third floor of 1 Market Way, London EC2A 1AA, approx. 2,580 sq ft: six offices, a meeting room, kitchenette, two WCs and a windowless server room, plus a basement store of 86 sq ft. Their condition is recorded in the schedule of condition.' }
                @{ Title = '2. Term'; Text = 'The term begins on {Termin} and runs for five years. The tenant may extend it once by five years by giving written notice at least six months before expiry. The lease is contracted out of the Landlord and Tenant Act 1954.' }
                @{ Title = '3. Rent and service charge'; Text = 'The rent is {Betrag} per month, plus a service charge on account of £4.00 per sq ft a year and VAT. Rent is payable in advance by the third working day of each month. The service charge is reconciled annually.' }
                @{ Title = '4. Rent deposit'; Text = 'The tenant pays a deposit of three months'' rent, held under a rent deposit deed. It is repaid once the premises have been handed back and all claims settled.' }
                @{ Title = '5. Use and alterations'; Text = 'The premises are used as the offices of an advertising agency; client visits and events until 22:00 are permitted. The tenant may install network cabling and cooling in the server room. The cabling stays in the premises at the end of the term without compensation. A company sign up to 60 x 40 cm at the entrance is permitted with the landlord''s consent.' }
                @{ Title = '6. Yielding up and general'; Text = 'At the end of the term the premises are handed back clean and tidy with all keys and access fobs. Any variation of this lease must be in writing.' }
            ) }
        @{ Title = 'Leasing Agreement, Multifunction Printer'; Party = 'Smith Office Supplies Ltd'; Sections = @(
                @{ Title = '1. Equipment'; Text = 'A3 colour multifunction device for printing, copying, scanning and faxing, 45 pages per minute, with finisher, set up for scan-to-folder and scan-to-email. Location: the London office; serial number as per the delivery note.' }
                @{ Title = '2. Term'; Text = 'The agreement begins on delivery on {Datum} and runs for 60 months. It cannot be terminated early for convenience.' }
                @{ Title = '3. Rental and page charges'; Text = 'The rental is {Betrag} per month plus VAT. It includes 3,000 black and white and 1,000 colour pages a month. Additional pages cost 0.8p and 5.5p respectively and are invoiced quarterly; the device reports its meter readings itself.' }
                @{ Title = '4. Service'; Text = 'Toner, wear parts, maintenance and repairs are included, paper is not. Toner is sent automatically at 15 % remaining. In the event of a fault an engineer is on site within eight working hours.' }
                @{ Title = '5. Network and storage'; Text = 'The lessee''s IT provider sets up the network and scan destinations; the lessor has no access to the internal network. The device stores jobs on an internal hard disk. On replacement or return the disk is wiped and a data erasure certificate is provided. No hard disk leaves the building without a certificate.' }
            ) }
        @{ Title = 'IT Support Agreement'; Party = 'Eastside IT Services Ltd'; Sections = @(
                @{ Title = '1. Scope'; Text = 'The supplier supports the IT of {Firma} in London and Manchester: two domain controllers, file server, mail server, 16 workstations and laptops, firewall, switches, Wi-Fi and the VPN between the offices. The asset list is Schedule 1.' }
                @{ Title = '2. Services'; Text = 'Monitoring of the servers and the backup every working day; monthly security updates in the maintenance window (second Wednesday from 19:00); helpdesk +44 20 7946 0777, Mon–Fri 8:00–18:00; a quarterly restore test with a written report; upkeep of the network documentation. Remote access to a workstation only when the person using it confirms.' }
                @{ Title = '3. Response times'; Text = 'Priority 1 (server or internet down at an office): call-back within 30 minutes, work starts within two hours. Priority 2 (single workstation): four hours. Priority 3 (requests, changes): next working day.' }
                @{ Title = '4. Charges'; Text = 'The fixed fee is {Betrag} per month plus VAT. Further work is charged at £85 per hour, outside service hours with a 50 % surcharge and only on the instructions of the directors.' }
                @{ Title = '5. Data protection'; Text = 'The supplier has access to personal data, including staff and client data. As a processor under Article 28 UK GDPR it processes it only on the customer''s instructions, uses sub-processors only with written consent and reports personal data breaches within 24 hours. At the end of the agreement it returns or verifiably deletes all data. The technical and organisational measures are Schedule 2.' }
                @{ Title = '6. Access and term'; Text = 'Each engineer works with a personal administrator account, never a shared one. If an engineer leaves, their account is disabled the same day. The agreement starts on {Datum}, runs for twelve months and renews for twelve months at a time unless terminated with three months'' notice before expiry.' }
            ) }
        @{ Title = 'Framework Agreement for Agency Services'; Party = '{Kunde}'; Sections = @(
                @{ Title = '1. Subject'; Text = 'This agreement covers all services that {Kunde} (the client) orders from {Firma} (the agency): concept, design, copywriting, artwork, social media and project management. Each order starts with a quote and a confirmation in writing; an email is sufficient.' }
                @{ Title = '2. Hourly rates'; Text = 'Per hour, excluding VAT: concept £95, graphic design £80, copywriting £75, project management £70, artwork £65. Time is billed in quarter hours. Rates are fixed for twelve months; after that the agency gives three months'' notice of changes, at most 5 % a year.' }
                @{ Title = '3. Approvals'; Text = 'Two rounds of amendments are included in the quote, further rounds are charged by time. Approvals are given in writing by {Ansprechpartner} or a named deputy. By approving for print, the client takes responsibility for content and spelling.' }
                @{ Title = '4. Intellectual property'; Text = 'On payment in full the client receives an exclusive, perpetual, worldwide licence to use the approved work in the media named in the order. Rejected designs remain with the agency. Third-party photos and fonts may only be used as licensed, e.g. two years print and online. The agency may show published work in its portfolio with the client''s consent.' }
                @{ Title = '5. Third-party costs and invoicing'; Text = 'The agency books printing, photography and media in the client''s name or, if agreed, in its own name with a 10 % handling fee. Invoices are issued monthly with a timesheet, payable within 14 days. The planned annual volume of {Budget} is not a purchase commitment.' }
                @{ Title = '6. Confidentiality and term'; Text = 'Campaigns before launch, prices and client data remain confidential. If the agency processes addresses for the client, e.g. for a mailing, a data processing agreement is signed first. This agreement applies from {Datum} for twelve months and renews for a year at a time unless either party gives three months'' notice before expiry. English law applies.' }
            ) }
    )

    ItDoc = @(
        @{ Title = 'File Server Migration Project Plan'; Text = 'Starting point: the old NAS from our early days is 94 % full, only knows "everyone may do everything" and is painfully slow from Manchester over the VPN.
Goal: a Windows file server with the shares Departments, Projects, Archive, Scans and Home$, permissions via groups only, previous versions, nightly backup.
1. Clean-up by {Vortermin}: each team deletes duplicates. Contacts are Emily Collins (London) and William Hughes (Manchester).
2. Build by {Datum}: server and groups by Eastside IT Services; management signs off the permissions concept.
3. Migration on {Termin}: from 16:00 on Friday the NAS is read-only, copying runs over the weekend, work starts Monday at 8:00.
4. Follow-up by {Termin2}: the NAS stays readable for four weeks, then it is switched off.
Risks: paths over 260 characters ("final_new_really_final"), image links in layouts pointing to old paths, deadlines in migration week. Hence a path list in advance, links checked in a test, and no migration in a trade fair week.' }
        @{ Title = 'Backup Concept'; Text = 'All file server shares are backed up, plus the system state of the domain controllers and the mail server. Not backed up: desktop, local documents, USB sticks.
Monday to Thursday at 22:00 incremental, Fridays full. We keep 14 daily, 8 weekly and 12 monthly backups. The weekly backup is also copied, encrypted, to Manchester, so that a burst pipe in London cannot hit server and backup at once.
Previous versions are created on working days at 7:00 and 12:00. Everyone can use them to get back files they overwrote by mistake; they do not replace a backup.
Restore test: once a quarter Eastside IT restores a randomly chosen project folder to a test path and compares it with the original. Duration and result go into the log, which the directors sign. A backup that has never been restored is just a hope.' }
        @{ Title = 'Network Documentation – Introduction'; Text = 'This documentation describes the network of {Firma} in London and Manchester. It is for Eastside IT Services and for anyone who needs to understand what is where in an emergency. Passwords are not in here; they are in the password safe.
London is the main office with the server room. The servers are on 10.0.1.0/24: domain controllers 10.0.1.4 and 10.0.1.6, mail server 10.0.1.5, file server 10.0.1.7. Workstations and printers get their addresses via DHCP. Manchester is connected by a permanent VPN and has no servers of its own.
The following chapters list devices, addresses and licences. Anyone who changes something records it the same day. As at: {Datum}.' }
        @{ Title = 'Laptop Handover Form'; Text = 'Issued to: {Mitarbeiter}, {Stelle}, start date {Eintritt}
Issued by: {Ich}, {Standort}, on {Datum}
Device: 14-inch laptop with charger, headset and bag. Asset no. CON-LT-____, serial no. ____________
Condition: new / used, defects: ____________
Checked together: sign-in with own account, password set by user, H: drive connected, email, printer, VPN, disk encryption active.
I have received the IT Policy. I will use the device for work only and will not pass it on. I will report loss or theft at once on +44 20 7946 0777. On my last working day I will return the device with all accessories.
Signed (issuer): ____________   Signed {Mitarbeiter}: ____________' }
    )

    KickoffSlide = @(
        @{ Title = 'Annual Kick-off'; Text = '{Firma}, London and Manchester
{Datum}, London meeting room, Manchester by video
Fred and Jane Bloggs
Breakfast for everyone afterwards, in Manchester it''s on the company' }
        @{ Title = 'Looking Back'; Text = 'That was {Jahr}:
52 projects completed, 11 of them for new clients
Biggest job: {Projekt} for {Kunde}
Our own website relaunched, first recruitment video for ourselves
Less good: a long-standing client gave notice in the autumn' }
        @{ Title = 'Figures'; Text = 'Turnover +{Prozent} % on last year
Average utilisation 81 %, over 100 % in November
Manchester share of turnover: 34 %
Unpaid invoices at year end: {Betrag}
Fewer sick days, thanks for getting well instead of soldiering on' }
        @{ Title = 'Three Goals, Not Ten'; Text = '1. Every regular client gets an annual review, not only when things are on fire
2. From the third round of amendments we charge, with a clear conscience
3. No deadlines after 16:00 on Fridays, exceptions only with advance warning' }
        @{ Title = 'New Clients and Projects'; Text = '{Kunde}: {Projekt}, starting {Termin}
Tender from an energy supplier: pitch on {Termin2}
Framework agreement with a Manchester client renewed
More enquiries from {Branche}, where we are building references' }
        @{ Title = 'Team'; Text = 'New on board: {Mitarbeiter} as {Stelle}
We are taking on apprentices again: business administration from September
Training: £850 per head, suggestions to your head of office
Team day in June in Manchester, bring a rain jacket' }
        @{ Title = 'Key Dates'; Text = 'Holiday requests in the team calendar by 31 January
Appraisals by the end of March
Classification training in February, one hour per office
Summer party on the last Friday before the London school holidays
Questions? Now, or later with Fred and Jane' }
    )
}
