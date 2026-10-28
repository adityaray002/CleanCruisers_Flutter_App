# CleanCruisers — AI image prompts

One prompt per image slot in the app. Paste each into Gemini, ChatGPT (image) or Midjourney,
save the result under the file name shown, and put it in `assets/images/`.

> **Keep the "Our work" gallery real.** The app labels it "Real photos from CleanCruisers jobs",
> so only your own job photos belong there. These AI images are for **service cards** (they show
> *what* a service is) and an optional people-free home hero.

---

## Before you start

**Size:** generate at **1600 × 1200 (4:3, landscape)** unless a slot says otherwise.
The app crops each image to a square thumbnail, a wide card and a 3:2 header, so **keep the
main subject in the centre**, with some space around it.

**Add this style block to the end of every prompt** so the whole set looks like one photoshoot:

```
Style: realistic smartphone photo, natural soft daylight, true-to-life colours, slight
depth of field, clean but real surroundings, Delhi residential society parking area.
Not CGI, not a 3D render, not over-saturated, no HDR glow. No text, no logos, no brand
badges, no watermarks, number plates blank or out of frame.
```

**If your tool supports a negative prompt, use:**

```
text, letters, logo, watermark, brand emblem, readable number plate, extra fingers,
distorted hands, warped car body, CGI, 3D render, cartoon, oversaturated, lens flare,
studio backdrop, showroom
```

**Check every image before using it** (these are what make AI photos look fake):
- Hands: 5 fingers, natural grip on the tool
- Car: wheels round, doors and panel lines straight, no melted or doubled parts
- No gibberish text on T-shirts, bottles or walls
- Water, foam and reflections behave naturally
- Faces: prefer shots where people are turned away or cropped. It looks more natural and avoids
  implying a specific person works for you

---

## Car wash

### 1. Exterior + Interior Wash → `svc_wash_full.jpg`
```
A white Indian hatchback (like a Maruti Swift, no badges) fully covered in thick white
snow-foam shampoo, parked in a tidy apartment society parking. A car-care worker in a plain
black T-shirt and dark trousers, seen from behind at the left of the frame, holds a foam
lance. Both front doors are open, showing a neat cabin. Morning light, wet concrete floor.
```

### 2. Exterior Wash → `svc_wash_exterior.jpg`
```
Close-up of a high-pressure water jet rinsing foam off the side of a silver sedan. The front
alloy wheel is in focus, droplets frozen mid-air, fan-shaped water spray, suds sliding down
the door. Only the worker's gloved hand and the spray gun are visible at the edge of the frame.
```

### 3. Interior Clean → `svc_wash_interior.jpg`
```
Inside a car cabin: a gloved hand vacuuming the driver-side floor carpet with a slim crevice
nozzle, black rubber footmat taken out and leaning against the door sill. Fabric seats,
clean dashboard softly out of focus. Daylight coming through the windscreen.
```

---

## Detailing & polish

### 4. Interior Dry Cleaning → `svc_dry_cleaning.jpg`
```
Close-up of a beige fabric car seat being shampooed: a soft detailing brush scrubbing a patch
of white foam on the seat. Half of the seat already clean and visibly brighter, a small
upholstery extractor nozzle resting nearby. Gloved hands, rear seat door open.
```

### 5. 3M Wax + Foam Wash → `svc_wax.jpg`
```
A gloved hand applying car wax with a round blue foam applicator pad in circular motion on the
bonnet of a glossy dark-grey SUV. A strip of freshly buffed paint shows mirror-like
reflections of trees and sky, next to a hazy unbuffed area. Folded microfibre towel on the bonnet.
```
*(Don't show a 3M bottle or logo. AI renders logos badly, and it shouldn't look like an official
3M image.)*

### 6. Rubbing + Foam Wash → `svc_rubbing.jpg`
```
A dual-action machine polisher with an orange foam pad working on the front door of a red
hatchback, a thin line of polishing compound on the paint. Half the panel dull and lightly
swirled, the polished half deep and glossy. Worker's forearms and gloves visible, face out of frame.
```

### 7. Rubbing + 3M Wax → `svc_rubbing_wax.jpg`
```
Low-angle close-up of the bonnet and front fender of a black SUV after polishing and waxing:
flawless mirror finish reflecting the sky and building balconies, fine water droplets beading
up on the surface. Society parking softly blurred behind.
```

### 8. Dry Cleaning + 3M Wax → `svc_dryclean_wax.jpg`
```
View through the open front door of a white sedan: spotless shampooed seats and a wiped,
matte-clean dashboard inside, while the glossy waxed door edge and fender shine in the
foreground. A folded microfibre cloth on the seat. Bright, clean, natural light.
```

### 9. Rubbing + Dry Cleaning → `svc_rubbing_dryclean.jpg`
```
A neat car-detailing kit laid out on a clean mat beside a grey hatchback: machine polisher,
foam pads, soft brushes, spray bottles without labels, a stack of folded microfibre towels
and a compact vacuum. The car's open rear door shows clean seats. Overhead three-quarter angle.
```

### 10. Full Detailing Package → `svc_full_detailing.jpg`
```
A freshly detailed dark-blue SUV in golden early-morning light in a tidy apartment society
parking, paint glossy with crisp reflections, tyres dressed deep black, windows spotless.
A car-care worker in a plain black T-shirt, seen from behind and slightly out of focus,
folding a microfibre towel near the rear of the car. Aspirational but realistic.
```

---

## Monthly plan

### 11. Monthly Plan · 3 Washes → `svc_monthly.jpg`
```
Early morning in a residential society parking: a car-care worker in a plain black T-shirt,
seen from behind, walks towards a row of parked cars carrying a bucket, a folded pressure
washer hose and microfibre towels. One car in front already clean and gleaming. Calm, routine,
reliable feeling.
```

---

## Optional: home hero (no people)

### 12. Home hero → `hero_foam.jpg` — **1200 × 1600 (3:4, portrait)**
```
Vertical photo, close-up of thick white snow-foam sliding down the bonnet and windscreen of a
dark car, water droplets catching soft morning light. The top half is the foamy car; the bottom
40% of the frame is darker and uncluttered (wet dark paint or shadow), so white text can sit on it.
```
The hero says *"Our team comes to your home"*, so it shouldn't show AI-made people who could be
taken for your team. A people-free foam close-up works. Your real branded-T-shirt team photo is
still the most trustworthy option.

---

## When you've added the files

Drop them into `assets/images/` with the names above and tell me. I'll wire each one to its
service and check that it crops well on every screen. You don't need to make all 12. Any you
skip will keep the current photo or illustration.
