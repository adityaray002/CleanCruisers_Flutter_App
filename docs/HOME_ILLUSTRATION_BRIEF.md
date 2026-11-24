# CleanCruisers: Home image set (brief)

## What makes Pronto's Home look premium

1. **Real-looking people, not cartoons.** Every picture is a photo-real person in the brand uniform.
2. **The same person, the same studio, every time.** One expert, one outfit, one light, one plain backdrop.
   Only the tool in their hands changes (bottles, mop, spray…). That is why the grid looks "designed".
3. **Cut out, no background.** The person is shot on a plain backdrop and cut out, so they sit cleanly on the green band
   or on a light tile. No street, no car park, no clutter behind them.
4. **Waist-up, looking at the camera, smiling.** Friendly and trustworthy, product held at chest height so it reads at tile size.
5. **3D clay icons for actions.** The lightning bolt and calendar are soft 3D objects, not flat icons and not photos.
6. **Brand colour only in the uniform and the band.** The pictures themselves stay neutral (white, grey, skin, uniform green).

Our current Home mixes three things (car-park photos, cartoon isometric cars, a van) and none of them is cut out.
The fix is a new image set made to these rules. Code can't fake it; the pictures have to be made this way.

## Two ways to get the pictures

**A. Real photoshoot (best, most trust).** One real CleanCruisers expert, 1 hour, a phone camera.
- Backdrop: plain white or light grey wall or a white bedsheet, 1.5 m behind the person. Daylight from a window at the side, no flash.
- Uniform: the dark green CleanCruisers polo and cap, black gloves, clean and ironed.
- Phone at chest height, 2 m away, portrait. Same spot, same light for every shot.

**B. AI images (fast).** Use the same tool that made our current photos, and give it `assets/images/hero_team_kit.jpg`
as the reference so it keeps the same face and uniform. Paste the style block before every prompt.

Either way: plain backdrop, so we can cut it out automatically.

## Style block (start of every AI prompt)

> Photorealistic studio photo of the same young Indian car-care expert as in the reference image: short black hair, friendly
> smile, dark green polo with the round green CleanCruisers logo on the chest, dark green cap, black nitrile gloves.
> Waist-up, facing the camera, body turned slightly to the left, holding the item at chest height.
> Plain seamless pure white studio background, soft even daylight from the left, gentle soft shadows, sharp focus,
> natural skin, no other people, no car, no text, no watermark, no brand logos on any product (plain unlabeled bottles).

## Shot list

| # | File | Used on | Pose / item (add after the style block) | Size |
|---|------|---------|------------------------------------------|------|
| 1 | `pro_hero.png` | Home band (big, right side) | Holding a green bucket filled with plain spray bottles, sponges and folded microfibre cloths, big confident smile. | 1024 × 1280 |
Tiles must show **the job being done on a car**, not just a tool in the hands, so the customer understands the
service at a glance. The car is a part only (door, seat, bonnet, wheel), cropped by the frame edge, in the same white studio.

| # | File | Used on | The job in the picture | Size |
|---|------|---------|------------------------|------|
| 2 | `pro_full_wash.png` | Popular: Exterior + Interior | Front door open: the car's outside half covered in foam, he vacuums the driver seat. | 1024 × 1024 |
| 3 | `pro_exterior.png` | Popular: Exterior Wash | He sprays thick white foam onto the side of a white car with a foam gun. | 1024 × 1024 |
| 4 | `pro_interior.png` | Popular: Interior Clean | He leans into the open front door, vacuuming the seat and floor mat. | 1024 × 1024 |
| 5 | `pro_bucket.png` | Popular: Bucket Wash | He wipes a soapy bonnet with a wash mitt; a green bucket of soapy water stands by the wheel. No hose. | 1024 × 1024 |
| 6 | `pro_dry_clean.png` | Detailing: Dry Cleaning | Close-up: he cleans a beige fabric seat with an extractor nozzle; a clear clean stripe where it passed. | 1024 × 1024 |
| 7 | `pro_rubbing.png` | Detailing: Rubbing | He polishes a dark bonnet with a polisher; left half dull with swirl marks, right half mirror glossy. | 1024 × 1024 |
| 8 | `pro_wax.png` | Detailing: Wax | He applies wax by hand on a dark glossy door; water beads and a mirror reflection on the paint. | 1024 × 1024 |
| 9 | `pro_full_package.png` | Detailing: Full package | He stands proudly beside the shining front of a dark sedan, tools neatly at his feet. | 1024 × 1024 |

The logo on the polo and cap must be our real logo: attach `assets/images/logo.png` and say "use exactly this logo,
do not write any other text". AI otherwise writes garbled words like "CLEANCRUIBERS".

### 3D icons for the two big action cards

Style: *"Soft 3D clay render icon, rounded shapes, matte surfaces with gentle glossy highlights, colours green #15803D,
mint #1DE874 and white, soft shadow below, plain pure white background, centred, no text, 1024 × 1024."*

| # | File | Card | Object |
|---|------|------|--------|
| 10 | `icon3d_wash.png` | Car wash | A small rounded car covered in white soap bubbles. |
| 11 | `icon3d_polish.png` | Detailing | A shiny round polisher pad with three sparkle stars. |
| 12 | `icon3d_calendar.png` | Monthly plan | A green calendar with a white tick on it. |

## Rules

- No real brand logos on cars, bottles or tools. The only logo allowed is ours on the uniform.
- No rating stars or review counts on our pictures (we don't show ratings until they are real).
- The same person in every shot. If one comes out with a different face, make it again.
- If you use AI, a real expert should still be the long-term goal: customers trust a real team more.

## When the files are ready

Put them in `assets/images/` with the names above (JPG or PNG on white). We cut them out, colour-match them,
and wire them into the new Home (mockup: `docs/home_redesign_mockup.jpg`).

## Trust photo (bottom of Home)

`trust_expert.png`, shown under "Relax, your car is in expert hands" once
`kTrustPhoto` in `lib/data/business_info.dart` points to it. Attach
`assets/images/pro_hero.png` as the reference for the same man and uniform.

> Same man, same face, same dark-green polo with the round CleanCruisers
> badge on the chest and the same dark-green cap as the reference photo.
> Waist-up, facing the camera, arms crossed, calm confident smile. Behind
> him a light-grey line drawing of a city: a few apartment blocks and a
> parked hatchback, thin grey lines only, no colour, fading into white at the
> edges. Pure white background #FFFFFF, soft studio light, photo-real person,
> no text, no other logos. Wide 3:2, the man in the centre, his body cut at
> the bottom edge of the image.
